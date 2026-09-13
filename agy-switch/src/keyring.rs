use crate::{Error, Result, token::Token};
use secret_service::{
    EncryptionType,
    blocking::{Collection, SecretService},
};
use std::collections::HashMap;
use zeroize::Zeroizing;

pub trait Backend {
    fn read(&self) -> Result<Option<Token>>;
    fn write(&self, token: &Token) -> Result<()>;
    fn clear(&self) -> Result<()>;
    fn save_profile(&self, id: &str, token: &Token) -> Result<()>;
    fn read_profile(&self, _id: &str) -> Result<Option<Token>> {
        Ok(None)
    }
}

pub struct Keyring<'a> {
    collection: Collection<'a>,
}
pub fn connect() -> Result<SecretService<'static>> {
    let connection = zbus::blocking::connection::Builder::session()
        .map_err(|_| Error::KeyringUnavailable)?
        .method_timeout(std::time::Duration::from_secs(10))
        .build()
        .map_err(|_| Error::KeyringUnavailable)?;
    SecretService::connect_with_existing(EncryptionType::Dh, connection)
        .map_err(|_| Error::KeyringUnavailable)
}

impl<'a> Keyring<'a> {
    pub fn open(service: &'a SecretService<'a>, unlock: bool) -> Result<Self> {
        let collection = service
            .get_default_collection()
            .map_err(|_| Error::KeyringUnavailable)?;
        if collection.collection_path.as_str().ends_with("/session") {
            return Err(Error::Message(
                "Default keyring points to volatile session storage; use a persistent collection"
                    .into(),
            ));
        }
        match collection.is_locked() {
            Ok(true) if unlock => {
                collection.unlock().map_err(|_| Error::KeyringLocked)?;
                collection
                    .ensure_unlocked()
                    .map_err(|_| Error::KeyringLocked)?;
            }
            Ok(true) => return Err(Error::KeyringLocked),
            Ok(false) => (),
            Err(_) => return Err(Error::KeyringUnavailable),
        }
        Ok(Self { collection })
    }
    fn attrs() -> HashMap<&'static str, &'static str> {
        HashMap::from([("service", "gemini"), ("username", "antigravity")])
    }
}

impl Backend for Keyring<'_> {
    fn read_profile(&self, id: &str) -> Result<Option<Token>> {
        let items = self
            .collection
            .search_items(HashMap::from([
                ("application", "agy-switch"),
                ("profile", id),
            ]))
            .map_err(|_| Error::KeyringUnavailable)?;
        if items.len() > 1 {
            return Err(Error::Message(
                "Duplicate saved profile credentials in keyring".into(),
            ));
        }
        items
            .first()
            .map(|item| {
                let raw = Zeroizing::new(item.get_secret().map_err(|_| Error::KeyringUnavailable)?);
                Token::parse(std::str::from_utf8(&raw).map_err(|_| Error::InvalidToken)?)
            })
            .transpose()
    }
    fn read(&self) -> Result<Option<Token>> {
        let items = self
            .collection
            .search_items(Self::attrs())
            .map_err(|_| Error::KeyringUnavailable)?;
        if items.len() > 1 {
            return Err(Error::Message(
                "Duplicate active credentials in the default keyring; refusing an ambiguous switch"
                    .into(),
            ));
        }
        items
            .first()
            .map(|item| {
                let secret =
                    Zeroizing::new(item.get_secret().map_err(|_| Error::KeyringUnavailable)?);
                Token::parse(std::str::from_utf8(&secret).map_err(|_| Error::InvalidToken)?)
            })
            .transpose()
    }
    fn write(&self, token: &Token) -> Result<()> {
        // Replace in the exact persistent collection. Never clear before writing.
        let item = self
            .collection
            .create_item(
                "Password for 'antigravity' on 'gemini'",
                Self::attrs(),
                token.raw().as_bytes(),
                true,
                "application/json",
            )
            .map_err(|_| Error::KeyringWrite)?;
        let raw = Zeroizing::new(item.get_secret().map_err(|_| Error::KeyringWrite)?);
        if raw.as_slice() != token.raw().as_bytes() {
            return Err(Error::Verification);
        }
        match self.read()? {
            Some(read) if read.raw() == token.raw() => Ok(()),
            _ => Err(Error::Verification),
        }
    }
    fn clear(&self) -> Result<()> {
        // Only for journaled login or rollback to a previously empty state.
        for item in self
            .collection
            .search_items(Self::attrs())
            .map_err(|_| Error::KeyringUnavailable)?
        {
            item.delete().map_err(|_| Error::KeyringWrite)?;
        }
        if self.read()?.is_some() {
            return Err(Error::Verification);
        }
        Ok(())
    }
    fn save_profile(&self, id: &str, token: &Token) -> Result<()> {
        let attrs = HashMap::from([("application", "agy-switch"), ("profile", id)]);
        let item = self
            .collection
            .create_item(
                &format!("agy-switch profile {id}"),
                attrs,
                token.raw().as_bytes(),
                true,
                "application/json",
            )
            .map_err(|_| Error::KeyringWrite)?;
        let raw = Zeroizing::new(item.get_secret().map_err(|_| Error::KeyringWrite)?);
        if raw.as_slice() != token.raw().as_bytes() {
            return Err(Error::Verification);
        }
        Ok(())
    }
}
