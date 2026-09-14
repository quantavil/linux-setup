use crate::{
    Error, Result, engine,
    keyring::Backend,
    store::{Store, atomic_write},
    token::Token,
};

#[test]
#[ignore = "Run through tests/keyring-restart.sh on an isolated D-Bus and data directory"]
fn real_keyring_restart() {
    let root = std::env::var_os("AGY_SWITCH_TEST_ROOT").expect("isolated test root required");
    let root = std::path::PathBuf::from(root);
    assert!(root.join("isolated-test-marker").is_file());
    assert_eq!(
        std::env::var_os("XDG_DATA_HOME").unwrap(),
        root.join("data").into_os_string()
    );
    let service = crate::keyring::connect().unwrap();
    let backend = crate::keyring::Keyring::open(&service, false).unwrap();
    // A different application can store multiline data in the shared collection.
    // Exercise the daemon's serializer, not just our compact OAuth JSON.
    let collection = service.get_default_collection().unwrap();
    let attributes = std::collections::HashMap::from([("application", "agy-switch-regression")]);
    let multiline = b"  synthetic secret\nsecond line\n\\n literal backslash\t\n";
    if std::env::var("AGY_SWITCH_TEST_PHASE").unwrap() == "seed" {
        collection
            .create_item(
                "Synthetic multiline secret",
                attributes.clone(),
                multiline,
                true,
                "text/plain",
            )
            .unwrap();
    } else {
        let items = collection.search_items(attributes).unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].get_secret().unwrap(), multiline);
    }
    let store = Store::open(&root.join("profiles-home")).unwrap();
    match std::env::var("AGY_SWITCH_TEST_PHASE").unwrap().as_str() {
        "seed" => {
            store.save("1", &token("one", 1)).unwrap();
            store.save("2", &token("two", 1)).unwrap();
            engine::switch(&store, &backend, "2").unwrap();
        }
        "restart" => {
            assert_eq!(backend.read().unwrap().unwrap().subject, "two");
            assert_eq!(backend.read_profile("2").unwrap().unwrap().subject, "two");
            // Recover a missing local profile from the persistent keyring copy.
            fs::remove_file(store.root.join("2/token.json")).unwrap();
            engine::switch(&store, &backend, "2").unwrap();
            assert_eq!(store.token("2").unwrap().unwrap().subject, "two");
            engine::switch(&store, &backend, "1").unwrap();
        }
        "verify" => {
            assert_eq!(backend.read().unwrap().unwrap().subject, "one");
            assert_eq!(store.current().unwrap().as_deref(), Some("1"));
        }
        _ => panic!("unknown test phase"),
    }
}
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use std::{
    cell::{Cell, RefCell},
    fs,
    os::unix::fs::PermissionsExt,
};

fn token(account: &str, generation: u32) -> Token {
    let payload = URL_SAFE_NO_PAD.encode(format!(
        r#"{{"sub":"{account}","email":"{account}@example.test"}}"#
    ));
    Token::parse(&format!(r#"{{"token":{{"access_token":"access-{generation}","refresh_token":"refresh-{account}"}},"id_token":"header.{payload}.signature"}}"#)).unwrap()
}
struct Fake {
    active: RefCell<Option<Token>>,
    writes: Cell<usize>,
    fail_at: Cell<usize>,
    fail_forever: Cell<bool>,
    clear_count: Cell<usize>,
    corrupt_write: Cell<bool>,
}
impl Fake {
    fn new(token: Token) -> Self {
        Self {
            active: RefCell::new(Some(token)),
            writes: Cell::new(0),
            fail_at: Cell::new(0),
            fail_forever: Cell::new(false),
            clear_count: Cell::new(0),
            corrupt_write: Cell::new(false),
        }
    }
}
impl Backend for Fake {
    fn read(&self) -> Result<Option<Token>> {
        Ok(self.active.borrow().clone())
    }
    fn write(&self, token: &Token) -> Result<()> {
        self.writes.set(self.writes.get() + 1);
        if self.fail_forever.get() || self.writes.get() == self.fail_at.get() {
            return Err(Error::KeyringWrite);
        }
        if !self.corrupt_write.get() {
            *self.active.borrow_mut() = Some(token.clone());
        }
        Ok(())
    }
    fn clear(&self) -> Result<()> {
        self.clear_count.set(self.clear_count.get() + 1);
        *self.active.borrow_mut() = None;
        Ok(())
    }
    fn save_profile(&self, _: &str, _: &Token) -> Result<()> {
        Ok(())
    }
}
fn fixture() -> (tempfile::TempDir, Store, Fake) {
    let home = tempfile::tempdir().unwrap();
    let store = Store::open(home.path()).unwrap();
    store.save("1", &token("one", 1)).unwrap();
    store.save("2", &token("two", 1)).unwrap();
    store.commit_current(Some("1")).unwrap();
    atomic_write(&store.fallback, token("one", 1).raw().as_bytes()).unwrap();
    let fake = Fake::new(token("one", 1));
    (home, store, fake)
}

#[test]
fn switch_verifies_both_stores_and_never_clears() {
    let (_home, store, fake) = fixture();
    engine::switch(&store, &fake, "2").unwrap();
    assert_eq!(store.current().unwrap().as_deref(), Some("2"));
    assert_eq!(fake.read().unwrap().unwrap().subject, "two");
    assert_eq!(
        Token::parse(&fs::read_to_string(&store.fallback).unwrap())
            .unwrap()
            .subject,
        "two"
    );
    assert_eq!(fake.clear_count.get(), 0);
    assert!(store.journal().unwrap().is_none());
}
#[test]
fn failed_write_restores_old_state_and_profiles() {
    let (_home, store, fake) = fixture();
    fake.fail_at.set(1);
    assert!(engine::switch(&store, &fake, "2").is_err());
    assert_eq!(store.current().unwrap().as_deref(), Some("1"));
    assert_eq!(fake.read().unwrap().unwrap().subject, "one");
    assert_eq!(store.token("2").unwrap().unwrap().subject, "two");
    assert!(store.journal().unwrap().is_none());
}
#[test]
fn persistent_failure_leaves_recovery_record_for_next_process() {
    let (home, store, fake) = fixture();
    fake.fail_forever.set(true);
    assert!(engine::switch(&store, &fake, "2").is_err());
    assert!(store.journal().unwrap().is_some());
    drop(store);
    let reopened = Store::open(home.path()).unwrap();
    fake.fail_forever.set(false);
    engine::recover(&reopened, &fake).unwrap();
    assert_eq!(reopened.current().unwrap().as_deref(), Some("1"));
    assert!(reopened.journal().unwrap().is_none());
}
#[test]
fn crash_after_keyring_write_rolls_back_on_reopen() {
    let (home, store, fake) = fixture();
    engine::prepare(&store, &fake, "2", "switch").unwrap();
    fake.write(&token("two", 1)).unwrap();
    drop(store);
    let reopened = Store::open(home.path()).unwrap();
    engine::recover(&reopened, &fake).unwrap();
    assert_eq!(fake.read().unwrap().unwrap().subject, "one");
    assert_eq!(reopened.current().unwrap().as_deref(), Some("1"));
}
#[test]
fn crash_after_marker_commit_still_recovers_consistently() {
    let (home, store, fake) = fixture();
    engine::prepare(&store, &fake, "2", "switch").unwrap();
    fake.write(&token("two", 1)).unwrap();
    atomic_write(&store.fallback, token("two", 1).raw().as_bytes()).unwrap();
    store.commit_current(Some("2")).unwrap();
    drop(store);
    let reopened = Store::open(home.path()).unwrap();
    engine::recover(&reopened, &fake).unwrap();
    assert_eq!(reopened.current().unwrap().as_deref(), Some("1"));
}
#[test]
fn stale_marker_cannot_overwrite_another_account() {
    let (_home, store, fake) = fixture();
    *fake.active.borrow_mut() = Some(token("two", 99));
    engine::snapshot(&store, &fake).unwrap();
    assert_eq!(store.token("1").unwrap().unwrap().subject, "one");
    assert_eq!(
        store.token("2").unwrap().unwrap().raw(),
        token("two", 99).raw()
    );
}
#[test]
fn no_false_success_when_backend_silently_drops_write() {
    let (_home, store, fake) = fixture();
    fake.corrupt_write.set(true);
    assert!(engine::switch(&store, &fake, "2").is_err());
    assert_eq!(store.current().unwrap().as_deref(), Some("1"));
}
#[test]
fn exclusive_lock_blocks_second_instance() {
    let (home, _store, _fake) = fixture();
    assert!(Store::open(home.path()).is_err());
}
#[test]
fn login_is_saved_before_cli_exits_and_recovers_after_crash() {
    let (home, store, fake) = fixture();
    let mut journal = engine::prepare(&store, &fake, "3", "login").unwrap();
    fake.clear().unwrap();
    store.restore_file(&store.fallback, None).unwrap();
    journal.login_ready = true;
    store.write_journal(&journal).unwrap();
    fake.write(&token("three", 1)).unwrap();
    assert!(engine::capture_login(&store, &fake, &mut journal).unwrap());
    assert_eq!(store.token("3").unwrap().unwrap().subject, "three");
    drop(store);
    let reopened = Store::open(home.path()).unwrap();
    engine::recover(&reopened, &fake).unwrap();
    assert_eq!(reopened.current().unwrap().as_deref(), Some("3"));
}
#[test]
fn crash_before_login_clear_cannot_import_old_fallback() {
    let (_home, store, fake) = fixture();
    let mut journal = engine::prepare(&store, &fake, "3", "login").unwrap();
    *fake.active.borrow_mut() = None;
    assert!(!engine::capture_login(&store, &fake, &mut journal).unwrap());
    assert!(store.token("3").unwrap().is_none());
    engine::recover(&store, &fake).unwrap();
    assert_eq!(fake.read().unwrap().unwrap().subject, "one");
}
#[test]
fn cancelled_login_restores_without_creating_profile() {
    let (_home, store, fake) = fixture();
    let mut journal = engine::prepare(&store, &fake, "3", "login").unwrap();
    fake.clear().unwrap();
    store.restore_file(&store.fallback, None).unwrap();
    journal.login_ready = true;
    store.write_journal(&journal).unwrap();
    engine::recover(&store, &fake).unwrap();
    assert!(store.token("3").unwrap().is_none());
    assert_eq!(fake.read().unwrap().unwrap().subject, "one");
}
#[test]
fn missing_profile_is_not_created_by_switch() {
    let (_home, store, fake) = fixture();
    assert!(engine::switch(&store, &fake, "3").is_err());
    assert!(!store.root.join("3").exists());
    assert!(store.journal().unwrap().is_none());
}
#[test]
fn migration_preserves_bytes_and_does_not_invent_profiles() {
    let home = tempfile::tempdir().unwrap();
    let path = home.path().join(".gemini/profiles/2/token.json");
    let raw = token("two", 1).raw().to_owned();
    atomic_write(&path, raw.as_bytes()).unwrap();
    let store = Store::open(home.path()).unwrap();
    assert_eq!(fs::read_to_string(path).unwrap(), raw);
    assert_eq!(store.profiles().unwrap().len(), 1);
    assert!(store.token("3").unwrap().is_none());
}
#[test]
fn sensitive_files_are_private() {
    let (_home, store, fake) = fixture();
    engine::prepare(&store, &fake, "2", "switch").unwrap();
    for p in [
        store.root.join("1/token.json"),
        store.root.join("pending.json"),
        store.root.join("state.sqlite3"),
    ] {
        assert_eq!(fs::metadata(p).unwrap().permissions().mode() & 0o777, 0o600);
    }
    assert_eq!(
        fs::metadata(&store.root).unwrap().permissions().mode() & 0o777,
        0o700
    );
}
#[test]
fn traversal_and_symlinks_are_rejected() {
    let (home, store, _fake) = fixture();
    assert!(store.token("../1").is_err());
    assert!(store.token("a/b").is_err());
    std::os::unix::fs::symlink(home.path(), store.root.join("evil")).unwrap();
    assert!(store.save("evil", &token("evil", 1)).is_err());
}
#[test]
fn invalid_token_error_does_not_disclose_secret() {
    let error = Token::parse("super-secret-invalid-token").err().unwrap();
    assert!(!error.to_string().contains("super-secret"));
}
#[test]
fn credentials_are_compacted_before_keyring_storage() {
    let raw = token("one", 1).raw().to_owned();
    let value: serde_json::Value = serde_json::from_str(&raw).unwrap();
    let pretty = serde_json::to_string_pretty(&value).unwrap();
    assert!(!Token::parse(&pretty).unwrap().raw().contains('\n'));
}
#[test]
fn fallback_write_failure_preserves_journal_until_repaired() {
    let (_home, store, fake) = fixture();
    fs::remove_file(&store.fallback).unwrap();
    fs::create_dir(&store.fallback).unwrap();
    // prepare rejects invalid fallback before any keyring mutation.
    assert!(engine::switch(&store, &fake, "2").is_err());
    assert_eq!(fake.writes.get(), 0);
    assert_eq!(store.current().unwrap().as_deref(), Some("1"));
}
