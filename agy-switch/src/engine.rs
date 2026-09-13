use crate::{
    Error, Result,
    keyring::Backend,
    store::{Journal, Store, atomic_write, read_optional, valid_id},
    token::Token,
};

pub fn snapshot(store: &Store, backend: &impl Backend) -> Result<()> {
    if let Some(active) = backend.read()? {
        // Attribute refreshed credentials to their identity, never a stale marker.
        let mut matched = false;
        for (id, _) in store.profiles()? {
            if let Some(saved) = store.token(&id)? {
                if saved.same_account(&active) {
                    store.save(&id, &active)?;
                    backend.save_profile(&id, &active)?;
                    matched = true;
                }
            }
        }
        if !matched && store.profiles()?.is_empty() {
            store.save("1", &active)?;
        }
    }
    Ok(())
}

pub fn prepare(store: &Store, backend: &impl Backend, target: &str, kind: &str) -> Result<Journal> {
    if store.journal()?.is_some() {
        return Err(Error::Message(
            "Recovery is pending; run agy-switch recover first".into(),
        ));
    }
    valid_id(target)?;
    let journal = Journal {
        kind: kind.into(),
        target: target.into(),
        previous: store.current()?,
        keyring: backend.read()?.map(|t| t.raw().to_owned()),
        fallback: read_optional(&store.fallback)?.map(|s| s.to_string()),
        captured: false,
        login_ready: false,
    };
    store.write_journal(&journal)?;
    Ok(journal)
}

pub fn restore(store: &Store, backend: &impl Backend, journal: &Journal) -> Result<()> {
    if let Some(raw) = &journal.keyring {
        backend.write(&Token::parse(raw)?)?;
    } else {
        backend.clear()?;
    }
    store.restore_file(&store.fallback, journal.fallback.as_deref())?;
    store.commit_current(journal.previous.as_deref())?;
    store.finish()
}

pub fn activate(store: &Store, backend: &impl Backend, id: &str, token: &Token) -> Result<()> {
    backend.save_profile(id, token)?;
    backend.write(token)?;
    atomic_write(&store.fallback, token.raw().as_bytes())?;
    let read = read_optional(&store.fallback)?.ok_or(Error::Verification)?;
    if read.as_str() != token.raw() {
        return Err(Error::Verification);
    }
    // Recheck after writing the file, before committing the marker.
    if !backend.read()?.is_some_and(|t| t.raw() == token.raw()) {
        return Err(Error::Verification);
    }
    store.commit_current(Some(id))?;
    store.finish()
}

pub fn switch(store: &Store, backend: &impl Backend, id: &str) -> Result<()> {
    if store.token(id)?.is_none() {
        if let Some(saved) = backend.read_profile(id)? {
            store.save(id, &saved)?;
        }
    }
    let _target = store.token(id)?.ok_or_else(|| {
        Error::Message(format!(
            "Profile [{id}] has no saved credentials; run agy-switch login {id}"
        ))
    })?;
    recover(store, backend)?;
    snapshot(store, backend)?;
    let target = store.token(id)?.ok_or(Error::InvalidToken)?;
    let journal = prepare(store, backend, id, "switch")?;
    if let Err(error) = activate(store, backend, id, &target) {
        return match restore(store, backend, &journal) {
            Ok(()) => Err(Error::Message(format!(
                "{error}; previous active state restored"
            ))),
            Err(_) => Err(Error::Message(format!(
                "{error}; recovery pending. Saved profiles are intact. Run agy-switch recover when the keyring is available"
            ))),
        };
    }
    println!("Switched to Profile [{id}] {}", target.email);
    Ok(())
}

pub fn capture_login(store: &Store, backend: &impl Backend, journal: &mut Journal) -> Result<bool> {
    if !journal.login_ready {
        return Ok(false);
    }
    let token = match backend.read()? {
        Some(token) => Some(token),
        None => read_optional(&store.fallback)?
            .map(|raw| Token::parse(&raw))
            .transpose()?,
    };
    if let Some(token) = token {
        if !token.refreshable() {
            return Ok(false);
        }
        // Do not mistake credentials that failed to clear for a fresh login.
        if journal.keyring.as_deref() == Some(token.raw())
            || journal
                .fallback
                .as_deref()
                .and_then(|s| Token::parse(s).ok())
                .is_some_and(|t| t.raw() == token.raw())
        {
            return Ok(false);
        }
        if journal.captured
            && store
                .token(&journal.target)?
                .is_some_and(|saved| !saved.same_account(&token))
        {
            return Err(Error::Message(
                "Active account changed during login; saved credentials retained".into(),
            ));
        }
        store.save(&journal.target, &token)?;
        journal.captured = true;
        store.write_journal(journal)?;
        return Ok(true);
    }
    Ok(false)
}

pub fn recover(store: &Store, backend: &impl Backend) -> Result<()> {
    if let Some(mut journal) = store.journal()? {
        if journal.kind == "login" {
            if !journal.captured {
                capture_login(store, backend, &mut journal)?;
            }
            if journal.captured {
                let token = store.token(&journal.target)?.ok_or(Error::InvalidToken)?;
                activate(store, backend, &journal.target, &token)?;
                println!("Recovered saved login for Profile [{}]", journal.target);
                return Ok(());
            }
        }
        restore(store, backend, &journal)?;
        println!("Recovered previous active state.");
    }
    Ok(())
}
