use crate::{Error, Result};
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use serde_json::Value;
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

// No Debug or Display implementation: error messages must never expose credentials.
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct Token {
    raw: String,
    pub subject: String,
    pub email: String,
}

impl Token {
    pub fn parse(raw: &str) -> Result<Self> {
        let mut value: Value = serde_json::from_str(raw).map_err(|_| Error::InvalidToken)?;
        let refresh = value
            .pointer("/token/refresh_token")
            .and_then(Value::as_str);
        let access = value.pointer("/token/access_token").and_then(Value::as_str);
        if !refresh.is_some_and(|s| !s.is_empty()) && !access.is_some_and(|s| !s.is_empty()) {
            return Err(Error::InvalidToken);
        }
        let payload = value
            .get("id_token")
            .and_then(Value::as_str)
            .and_then(|s| s.split('.').nth(1))
            .and_then(|s| URL_SAFE_NO_PAD.decode(s.trim_end_matches('=')).ok());
        let identity: Value = payload
            .and_then(|p| serde_json::from_slice(&p).ok())
            .unwrap_or(Value::Null);
        let subject = identity
            .get("sub")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_owned();
        let email = identity
            .get("email")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_owned();
        // Compact JSON avoids the multiline secret bug observed in GNOME Keyring 50.
        let compact = serde_json::to_string(&value).map_err(|_| Error::InvalidToken)?;
        wipe_json(&mut value);
        Ok(Self {
            raw: compact,
            subject,
            email,
        })
    }
    pub fn raw(&self) -> &str {
        &self.raw
    }
    pub fn same_account(&self, other: &Self) -> bool {
        if !self.subject.is_empty() && !other.subject.is_empty() {
            self.subject == other.subject
        } else {
            self.raw == other.raw
        }
    }
    pub fn refreshable(&self) -> bool {
        let raw = Zeroizing::new(self.raw.clone());
        let mut v: Value = serde_json::from_str(&raw).unwrap_or(Value::Null);
        let result = v
            .pointer("/token/refresh_token")
            .and_then(Value::as_str)
            .is_some_and(|s| !s.is_empty());
        wipe_json(&mut v);
        result
    }
}

fn wipe_json(v: &mut Value) {
    match v {
        Value::String(s) => s.zeroize(),
        Value::Array(a) => a.iter_mut().for_each(wipe_json),
        Value::Object(o) => o.values_mut().for_each(wipe_json),
        _ => (),
    }
}
