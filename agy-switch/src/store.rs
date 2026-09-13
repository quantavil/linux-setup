use crate::{Error, Result, token::Token};
use fs2::FileExt;
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use std::{
    fs::{self, File, OpenOptions},
    io::Write,
    os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt},
    path::{Path, PathBuf},
};
use zeroize::Zeroizing;

pub fn valid_id(id: &str) -> Result<()> {
    if id.is_empty()
        || id.len() > 32
        || !id
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-')
    {
        return Err(Error::Message(
            "Profile IDs must contain 1–32 letters, digits, '-' or '_'".into(),
        ));
    }
    Ok(())
}

pub fn private_dir(path: &Path) -> Result<()> {
    if path
        .symlink_metadata()
        .is_ok_and(|m| m.file_type().is_symlink())
    {
        return Err(Error::Message(
            "Refusing symlinked credential directory".into(),
        ));
    }
    if !path.exists() {
        let parent = path
            .parent()
            .ok_or_else(|| Error::Message("Missing directory parent".into()))?;
        if !parent.exists() {
            private_dir(parent)?;
        }
        fs::DirBuilder::new().mode(0o700).create(path)?;
        // Persist the directory entry itself, including a newly created profile.
        File::open(parent)?.sync_all()?;
    }
    fs::set_permissions(path, fs::Permissions::from_mode(0o700))?;
    Ok(())
}

pub fn atomic_write(path: &Path, bytes: &[u8]) -> Result<()> {
    let parent = path
        .parent()
        .ok_or_else(|| Error::Message("Missing parent directory".into()))?;
    private_dir(parent)?;
    let mut tmp = tempfile::NamedTempFile::new_in(parent)?;
    tmp.as_file()
        .set_permissions(fs::Permissions::from_mode(0o600))?;
    tmp.write_all(bytes)?;
    tmp.as_file().sync_all()?;
    tmp.persist(path).map_err(|e| Error::Io(e.error))?;
    File::open(parent)?.sync_all()?;
    Ok(())
}

pub fn read_optional(path: &Path) -> Result<Option<Zeroizing<String>>> {
    match fs::symlink_metadata(path) {
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(e) => return Err(e.into()),
        Ok(m) if !m.is_file() || m.len() > 1024 * 1024 => {
            return Err(Error::Message(
                "Invalid credential file type or size".into(),
            ));
        }
        _ => (),
    }
    Ok(Some(Zeroizing::new(fs::read_to_string(path)?)))
}

#[derive(Serialize, Deserialize)]
pub struct Journal {
    pub kind: String,
    pub target: String,
    pub previous: Option<String>,
    pub keyring: Option<String>,
    pub fallback: Option<String>,
    pub captured: bool,
    #[serde(default)]
    pub login_ready: bool,
}
impl Drop for Journal {
    fn drop(&mut self) {
        use zeroize::Zeroize;
        self.keyring.zeroize();
        self.fallback.zeroize();
    }
}

pub struct Store {
    pub root: PathBuf,
    pub fallback: PathBuf,
    db: Connection,
    _lock: File,
}

impl Store {
    pub fn open(home: &Path) -> Result<Self> {
        let root = home.join(".gemini/profiles");
        private_dir(&root)?;
        let lock_path = root.join(".lock");
        if lock_path
            .symlink_metadata()
            .is_ok_and(|m| m.file_type().is_symlink())
        {
            return Err(Error::Message("Refusing symlinked lock".into()));
        }
        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .mode(0o600)
            .open(lock_path)?;
        lock.try_lock_exclusive()
            .map_err(|_| Error::Message("Another agy-switch operation is running".into()))?;
        let db_path = root.join("state.sqlite3");
        if db_path.symlink_metadata().is_ok_and(|m| !m.is_file()) {
            return Err(Error::Message("Invalid database path".into()));
        }
        let db = Connection::open(&db_path)?;
        fs::set_permissions(db_path, fs::Permissions::from_mode(0o600))?;
        db.execute_batch("PRAGMA synchronous=FULL; PRAGMA journal_mode=DELETE;
            CREATE TABLE IF NOT EXISTS profiles(id TEXT PRIMARY KEY, subject TEXT NOT NULL, email TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS state(key TEXT PRIMARY KEY, value TEXT NOT NULL);")?;
        let store = Self {
            root,
            fallback: home.join(".gemini/antigravity-cli/antigravity-oauth-token"),
            db,
            _lock: lock,
        };
        store.import_legacy()?;
        Ok(store)
    }
    fn import_legacy(&self) -> Result<()> {
        for entry in fs::read_dir(&self.root)? {
            let entry = entry?;
            let id = entry.file_name().to_string_lossy().into_owned();
            if !entry.file_type()?.is_dir() || valid_id(&id).is_err() {
                continue;
            }
            if let Some(raw) = read_optional(&entry.path().join("token.json"))? {
                match Token::parse(&raw) {
                    Ok(token) => {
                        private_dir(&entry.path())?;
                        fs::set_permissions(
                            entry.path().join("token.json"),
                            fs::Permissions::from_mode(0o600),
                        )?;
                        self.record(&id, &token)?;
                    }
                    Err(_) => eprintln!(
                        "Profile [{id}] has an invalid saved token; original file retained."
                    ),
                }
            }
        }
        if self.current()?.is_none()
            && self
                .db
                .query_row("SELECT value FROM state WHERE key='imported'", [], |r| {
                    r.get::<_, String>(0)
                })
                .optional()?
                .is_none()
        {
            if let Some(id) = read_optional(&self.root.join("current"))? {
                let id = id.trim();
                if valid_id(id).is_ok() && self.token(id)?.is_some() {
                    self.commit_current(Some(id))?;
                }
            }
            self.db
                .execute("INSERT OR REPLACE INTO state VALUES('imported','1')", [])?;
        }
        Ok(())
    }
    pub fn record(&self, id: &str, token: &Token) -> Result<()> {
        self.db.execute("INSERT INTO profiles VALUES(?1,?2,?3) ON CONFLICT(id) DO UPDATE SET subject=excluded.subject,email=excluded.email", params![id,token.subject,token.email])?;
        Ok(())
    }
    pub fn save(&self, id: &str, token: &Token) -> Result<()> {
        valid_id(id)?;
        if !token.refreshable() {
            return Err(Error::Message(
                "Credentials have no refresh token; refusing a non-durable profile".into(),
            ));
        }
        let path = self.root.join(id).join("token.json");
        // Keep one last-known version when agy refreshes or login replaces credentials.
        if let Some(old) = read_optional(&path)? {
            if Token::parse(&old).is_ok() && old.trim() != token.raw() {
                atomic_write(&path.with_file_name("token.previous.json"), old.as_bytes())?;
            }
        }
        atomic_write(&path, token.raw().as_bytes())?;
        self.record(id, token)
    }
    pub fn token(&self, id: &str) -> Result<Option<Token>> {
        valid_id(id)?;
        read_optional(&self.root.join(id).join("token.json"))?
            .map(|r| Token::parse(&r))
            .transpose()
    }
    pub fn profiles(&self) -> Result<Vec<(String, String)>> {
        let mut statement = self
            .db
            .prepare("SELECT id,email FROM profiles ORDER BY length(id),id")?;
        Ok(statement
            .query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect::<std::result::Result<Vec<_>, _>>()?)
    }
    pub fn current(&self) -> Result<Option<String>> {
        Ok(self
            .db
            .query_row("SELECT value FROM state WHERE key='current'", [], |r| {
                r.get(0)
            })
            .optional()?)
    }
    pub fn commit_current(&self, id: Option<&str>) -> Result<()> {
        if let Some(id) = id {
            self.db
                .execute("INSERT OR REPLACE INTO state VALUES('current',?1)", [id])?;
            atomic_write(&self.root.join("current"), format!("{id}\n").as_bytes())?;
        } else {
            self.db
                .execute("DELETE FROM state WHERE key='current'", [])?;
            self.restore_file(&self.root.join("current"), None)?;
        }
        Ok(())
    }
    pub fn journal(&self) -> Result<Option<Journal>> {
        read_optional(&self.root.join("pending.json"))?
            .map(|r| {
                serde_json::from_str(&r).map_err(|_| {
                    Error::Message(
                        "Recovery record is damaged; preserving it for manual recovery".into(),
                    )
                })
            })
            .transpose()
    }
    pub fn write_journal(&self, journal: &Journal) -> Result<()> {
        let bytes = Zeroizing::new(
            serde_json::to_vec(journal)
                .map_err(|_| Error::Message("Cannot serialize recovery record".into()))?,
        );
        atomic_write(&self.root.join("pending.json"), &bytes)
    }
    pub fn finish(&self) -> Result<()> {
        self.restore_file(&self.root.join("pending.json"), None)
    }
    pub fn restore_file(&self, path: &Path, raw: Option<&str>) -> Result<()> {
        if let Some(raw) = raw {
            atomic_write(path, raw.as_bytes())
        } else {
            match fs::remove_file(path) {
                Ok(()) => {
                    File::open(
                        path.parent()
                            .ok_or_else(|| Error::Message("Missing parent".into()))?,
                    )?
                    .sync_all()?;
                }
                Err(e) if e.kind() == std::io::ErrorKind::NotFound => (),
                Err(e) => return Err(e.into()),
            }
            Ok(())
        }
    }
}
