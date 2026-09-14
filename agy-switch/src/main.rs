mod engine;
mod keyring;
mod store;
#[cfg(test)]
mod tests;
mod token;

use clap::Parser;
use keyring::{Backend, Keyring};
use std::{
    path::PathBuf,
    process::{Command, ExitCode},
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::Duration,
};
use store::Store;

#[derive(thiserror::Error, Debug)]
pub enum Error {
    #[error("Filesystem operation failed: {0}")]
    Io(#[from] std::io::Error),
    #[error("Profile database operation failed: {0}")]
    Sql(#[from] rusqlite::Error),
    #[error("Saved credentials are invalid; original files were retained")]
    InvalidToken,
    #[error(
        "Default Secret Service collection is missing or unavailable; saved profiles are intact. Check journalctl --user -u gnome-keyring-daemon.service. If it reports an invalid keyring format, see the GNOME Keyring repair instructions in linux-setup/agy-switch/README.md; recover requires a working keyring"
    )]
    KeyringUnavailable,
    #[error("Default keyring is locked or unlocking was cancelled")]
    KeyringLocked,
    #[error("Secret Service write failed")]
    KeyringWrite,
    #[error("Credential read-back verification failed")]
    Verification,
    #[error("{0}")]
    Message(String),
}
pub type Result<T> = std::result::Result<T, Error>;

#[derive(Parser)]
#[command(
    version,
    about = "Recoverable Antigravity CLI account switcher",
    after_help = "Commands: <profile>, switch <profile>, status, whoami, login <profile>, recover, doctor, migrate\nClose running agy sessions before switch/login/recover. Existing profiles migrate automatically."
)]
struct Args {
    #[arg(required = true, allow_hyphen_values = true)]
    command: String,
    profile: Option<String>,
}

fn ensure_agy_stopped() -> Result<()> {
    // /proc inspection avoids pgrep dependency and never prints command lines.
    for entry in std::fs::read_dir("/proc")? {
        let entry = entry?;
        if !entry
            .file_name()
            .to_string_lossy()
            .bytes()
            .all(|b| b.is_ascii_digit())
        {
            continue;
        }
        let status = match std::fs::read_to_string(entry.path().join("status")) {
            Ok(s) => s,
            Err(_) => continue,
        };
        let own = std::fs::metadata("/proc/self")?;
        use std::os::unix::fs::MetadataExt;
        if std::fs::metadata(entry.path()).is_ok_and(|m| m.uid() == own.uid())
            && status.lines().any(|s| s == "Name:\tagy")
            && !status.lines().any(|s| s.starts_with("State:\tZ"))
        {
            return Err(Error::Message("An agy process is running. Exit it before changing accounts so it cannot overwrite credentials during a refresh".into()));
        }
    }
    Ok(())
}

fn login(store: &Store, backend: &impl Backend, id: &str) -> Result<()> {
    store::valid_id(id)?;
    engine::recover(store, backend)?;
    engine::snapshot(store, backend)?;
    let mut journal = engine::prepare(store, backend, id, "login")?;
    let interrupted = Arc::new(AtomicBool::new(false));
    let flag = interrupted.clone();
    ctrlc::set_handler(move || flag.store(true, Ordering::SeqCst))
        .map_err(|_| Error::Message("Cannot install login cancellation handler".into()))?;
    let result = (|| -> Result<()> {
        backend.clear()?;
        store.restore_file(&store.fallback, None)?;
        journal.login_ready = true;
        store.write_journal(&journal)?;
        println!(
            "Sign in to the account for Profile [{id}] in agy. Credentials will be saved as soon as authentication finishes. Exit agy to complete activation."
        );
        let mut child = Command::new("agy").spawn()?;
        let mut capture_error = None;
        loop {
            if !journal.captured {
                match engine::capture_login(store, backend, &mut journal) {
                    Ok(true) => {
                        println!("Profile [{id}] credentials saved durably. Exit agy to finish.")
                    }
                    Ok(false) => (),
                    Err(e) => {
                        capture_error = Some(e);
                    }
                }
            }
            if child.try_wait()?.is_some() {
                break;
            }
            if interrupted.load(Ordering::SeqCst) {
                child.kill()?;
                child.wait()?;
                break;
            }
            std::thread::sleep(Duration::from_millis(300));
        }
        // Save a final refresh generated after the first authentication capture.
        let captured = engine::capture_login(store, backend, &mut journal)?;
        if !captured && !journal.captured {
            return Err(capture_error.unwrap_or_else(|| {
                Error::Message("Login cancelled or produced no refreshable credentials".into())
            }));
        }
        let token = store.token(id)?.ok_or(Error::InvalidToken)?;
        engine::activate(store, backend, id, &token)?;
        println!("Profile [{id}] saved and activated: {}", token.email);
        Ok(())
    })();
    if let Err(error) = result {
        // Once captured, retain the journal so recovery can activate the saved login.
        if journal.captured {
            return Err(Error::Message(format!(
                "{error}; Profile [{id}] was saved. Run agy-switch recover to finish activation"
            )));
        }
        return match engine::restore(store, backend, &journal) {
            Ok(()) => Err(Error::Message(format!(
                "{error}; previous active state restored"
            ))),
            Err(_) => Err(Error::Message(format!(
                "{error}; recovery pending; saved profiles retained"
            ))),
        };
    }
    Ok(())
}

fn status(store: &Store, whoami: bool) -> Result<()> {
    let service = keyring::connect();
    let active = match &service {
        Ok(s) => Keyring::open(s, false).and_then(|k| k.read()),
        Err(_) => Err(Error::KeyringUnavailable),
    };
    let pending = store.journal()?.is_some();
    if pending {
        println!("Recovery pending: run agy-switch recover before using agy.");
    }
    let marker = store.current()?;
    let mut verified = false;
    for (id, email) in store.profiles()? {
        let saved = store.token(&id);
        let state = match (&saved, &active) {
            (Ok(Some(token)), Ok(Some(active))) if token.same_account(active) && !pending => {
                "active account verified"
            }
            (Ok(Some(_)), _) => "saved",
            (Ok(None), _) => "credential file missing",
            (Err(_), _) => "credential file invalid",
        };
        if !whoami || state == "active account verified" {
            println!(
                "[{id}] {email} — {state}{}",
                if marker.as_deref() == Some(&id) {
                    " (selected)"
                } else {
                    ""
                }
            );
        }
        verified |= state == "active account verified";
    }
    if let Err(e) = active {
        println!("Active account unverified: {e}");
        if whoami {
            return Err(e);
        }
    } else if matches!(active, Ok(None)) {
        println!("No active keyring credential.");
    }
    if whoami && !verified {
        return Err(Error::Message(
            "No saved profile matches a verified active account".into(),
        ));
    }
    Ok(())
}

fn run() -> Result<()> {
    let args = Args::parse();
    if args.profile.is_some() && !matches!(args.command.as_str(), "login" | "switch") {
        return Err(Error::Message(
            "Unexpected extra argument; use agy-switch --help".into(),
        ));
    }
    let home = PathBuf::from(
        std::env::var_os("HOME").ok_or_else(|| Error::Message("HOME is not set".into()))?,
    );
    let store = Store::open(&home)?;
    match args.command.as_str() {
        "migrate" => {
            if store.journal()?.is_some() {
                return Err(Error::Message(
                    "Finish pending recovery before migrating keyring copies".into(),
                ));
            }
            let service = keyring::connect()?;
            let backend = Keyring::open(&service, true)?;
            let mut count = 0;
            for (id, _) in store.profiles()? {
                if let Some(token) = store.token(&id)? {
                    backend.save_profile(&id, &token)?;
                    count += 1;
                }
            }
            println!(
                "Verified {count} persistent profile copies; existing credential files retained."
            );
            Ok(())
        }
        "status" | "list" | "ls" | "-s" | "--status" => status(&store, false),
        "whoami" | "current" | "me" => status(&store, true),
        "doctor" => {
            status(&store, false)?;
            println!(
                "Storage: {} (private files, SQLite metadata, durable recovery record)",
                store.root.display()
            );
            println!(
                "Profile backups contain OAuth secrets protected by file permissions, not encryption."
            );
            for (id, _) in store.profiles()? {
                if let Some(t) = store.token(&id)? {
                    println!(
                        "[{id}] refresh token: {}",
                        if t.refreshable() {
                            "present"
                        } else {
                            "MISSING — reauthenticate"
                        }
                    );
                }
            }
            ensure_agy_stopped()?;
            let service = keyring::connect()?;
            let backend = Keyring::open(&service, false)?;
            backend.read()?;
            if store.journal()?.is_some() {
                return Err(Error::Message("Recovery pending".into()));
            }
            println!("Keyring healthy; no recovery pending.");
            Ok(())
        }
        command => {
            let id = if command == "switch" || command == "login" {
                args.profile.as_deref().ok_or_else(|| {
                    Error::Message(format!("Usage: agy-switch {command} <profile>"))
                })?
            } else {
                command
            };
            if command != "recover" {
                store::valid_id(id)?;
            }
            ensure_agy_stopped()?;
            let service = keyring::connect()?;
            let backend = Keyring::open(&service, true)?;
            if command == "recover" {
                engine::recover(&store, &backend)
            } else if command == "login" {
                login(&store, &backend, id)
            } else {
                engine::switch(&store, &backend, id)
            }
        }
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("Error: {e}");
            ExitCode::FAILURE
        }
    }
}
