#!/usr/bin/env python3
"""
agy-switch: Fast account switcher for Antigravity CLI (agy).
Swaps active Pro credentials in the system Secret Service keyring.
"""

import base64
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

PROFILES_DIR = Path.home() / ".gemini" / "profiles"
CURRENT_FILE = PROFILES_DIR / "current"
CLI_TOKEN_FILE = Path.home() / ".gemini" / "antigravity-cli" / "antigravity-oauth-token"
KEYRING_SERVICE = "gemini"
KEYRING_USERNAME = "antigravity"
KEYRING_LABEL = "Password for 'antigravity' on 'gemini'"
KEYRING_ATTRS = ["service", KEYRING_SERVICE, "username", KEYRING_USERNAME]

# Terminal colors
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
DIM = "\033[2m"
RESET = "\033[0m"

PROFILE_ID_REGEX = re.compile(r"^[a-zA-Z0-9_-]{1,32}$")


def validate_profile_id(profile_id: str) -> str:
    pid = str(profile_id).strip()
    if not PROFILE_ID_REGEX.match(pid) or pid in (".", ".."):
        raise ValueError(f"Invalid profile ID '{profile_id}'. Use alphanumeric, '-' or '_' (1-32 chars).")
    return pid


def write_file_atomic(path: Path, content: str, mode: int = 0o600):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    tmp = path.with_name(f".tmp.{os.getpid()}.{path.name}")
    tmp.write_text(content)
    tmp.chmod(mode)
    tmp.replace(path)


def is_valid_token(raw: str) -> bool:
    if not raw:
        return False
    try:
        d = json.loads(raw)
        tok = d.get("token", {})
        return bool(tok.get("access_token") or tok.get("refresh_token"))
    except Exception:
        return False


def get_keyring_token() -> str:
    """Read active token from Linux Secret Service keyring."""
    if not shutil.which("secret-tool"):
        return ""
    try:
        r = subprocess.run(
            ["secret-tool", "lookup", *KEYRING_ATTRS],
            capture_output=True,
            text=True,
            check=False,
            timeout=3,
        )
        return r.stdout.strip()
    except Exception:
        return ""


def unlock_keyring():
    """Attempt to unlock default collection if locked (passwordless keyrings unlock silently)."""
    try:
        import dbus
        bus = dbus.SessionBus()
        service = bus.get_object("org.freedesktop.secrets", "/org/freedesktop/secrets")
        secrets = dbus.Interface(service, "org.freedesktop.Secret.Service")
        secrets.Unlock([dbus.ObjectPath("/org/freedesktop/secrets/aliases/default")])
    except Exception:
        pass


def set_keyring_token(secret_json: str) -> bool:
    """Store token in Linux Secret Service default keyring (used by agy's zalando/go-keyring)."""
    if not secret_json or not shutil.which("secret-tool"):
        return False
    unlock_keyring()
    # Clear first to ensure clean state and avoid duplicate/stale entries across collections
    clear_keyring_token()
    try:
        r = subprocess.run(
            ["secret-tool", "store", f"--label={KEYRING_LABEL}", *KEYRING_ATTRS],
            input=secret_json,
            capture_output=True,
            text=True,
            check=False,
            timeout=5,
        )
        return r.returncode == 0
    except Exception:
        return False


def clear_keyring_token() -> bool:
    """Clear active token in Linux Secret Service keyring."""
    if not shutil.which("secret-tool"):
        return True
    try:
        r = subprocess.run(
            ["secret-tool", "clear", *KEYRING_ATTRS],
            capture_output=True,
            text=True,
            check=False,
            timeout=3,
        )
        return r.returncode == 0
    except Exception:
        return False


def get_active_token() -> str:
    """Read active credentials from Secret Service keyring or CLI fallback file."""
    raw = get_keyring_token()
    if is_valid_token(raw):
        return raw
    if CLI_TOKEN_FILE.exists():
        try:
            raw = CLI_TOKEN_FILE.read_text().strip()
            if is_valid_token(raw):
                return raw
        except Exception:
            pass
    return ""


def clear_active_tokens():
    """Clear active credentials in both Secret Service keyring and CLI fallback file."""
    clear_keyring_token()
    if CLI_TOKEN_FILE.exists():
        try:
            CLI_TOKEN_FILE.unlink()
        except Exception:
            pass


def extract_email_from_token(token_str: str) -> str:
    """Extract authenticated email from id_token JWT (instant, offline) with endpoint fallback."""
    if not token_str:
        return ""
    # 1. Decode id_token JWT payload directly (instant, offline)
    try:
        d = json.loads(token_str)
        id_tok = d.get("id_token")
        if id_tok and isinstance(id_tok, str) and "." in id_tok:
            parts = id_tok.split(".")
            if len(parts) >= 2:
                payload_b64 = parts[1]
                payload_b64 += "=" * ((4 - len(payload_b64) % 4) % 4)
                payload_json = base64.urlsafe_b64decode(payload_b64.encode()).decode("utf-8", errors="ignore")
                payload = json.loads(payload_json)
                if payload.get("email"):
                    return str(payload["email"])
    except Exception:
        pass

    # 2. Fallback: Query Google OAuth userinfo endpoint using access token
    try:
        d = json.loads(token_str)
        access_tok = d.get("token", {}).get("access_token")
        if not access_tok:
            return ""
        req = urllib.request.Request(
            "https://www.googleapis.com/oauth2/v3/userinfo",
            headers={"Authorization": f"Bearer {access_tok}"},
        )
        with urllib.request.urlopen(req, timeout=3) as resp:
            data = json.loads(resp.read().decode())
            return str(data.get("email") or "")
    except Exception:
        return ""


def get_profile_dir(profile_id: str) -> Path:
    pid = validate_profile_id(profile_id)
    p = PROFILES_DIR / pid
    p.mkdir(mode=0o700, parents=True, exist_ok=True)
    return p


def get_profile_token(profile_id: str) -> str:
    token_file = PROFILES_DIR / profile_id / "token.json"
    if token_file.exists():
        raw = token_file.read_text().strip()
        if is_valid_token(raw):
            return raw
    return ""


def get_profile_email(profile_id: str) -> str:
    token_str = get_profile_token(profile_id)
    if token_str:
        email = extract_email_from_token(token_str)
        if email:
            save_profile_meta(profile_id, email)
            return email
    meta_file = PROFILES_DIR / profile_id / "profile.json"
    if meta_file.exists():
        try:
            d = json.loads(meta_file.read_text())
            if d.get("email"):
                return str(d["email"])
        except Exception:
            pass
    return ""


def save_profile_meta(profile_id: str, email: str):
    p_dir = get_profile_dir(profile_id)
    meta = {"profile": profile_id, "email": email}
    write_file_atomic(p_dir / "profile.json", json.dumps(meta, indent=2), mode=0o644)


def save_active_to_profile(profile_id: str, fetch_email: bool = False):
    """Snapshot current active credentials into profile storage."""
    raw_token = get_active_token()
    if not is_valid_token(raw_token):
        return
    active_email = extract_email_from_token(raw_token)
    existing_token = get_profile_token(profile_id)
    if existing_token:
        existing_email = extract_email_from_token(existing_token)
        # Safety check: do not overwrite a profile with credentials belonging to a different account
        if existing_email and active_email and existing_email != active_email:
            return
    p_dir = get_profile_dir(profile_id)
    write_file_atomic(p_dir / "token.json", raw_token, mode=0o600)
    if active_email:
        save_profile_meta(profile_id, active_email)


def apply_profile(profile_id: str) -> bool:
    """Load profile credentials into system keyring and CLI token fallback file."""
    raw_token = get_profile_token(profile_id)
    if not is_valid_token(raw_token):
        return False
    if not set_keyring_token(raw_token):
        print(f"{RED}Error: Failed to store credentials in Secret Service keyring.{RESET}", file=sys.stderr)
        return False
    # Keep CLI token fallback file in sync so agy never falls back to an older cached session
    write_file_atomic(CLI_TOKEN_FILE, raw_token, mode=0o600)
    write_file_atomic(CURRENT_FILE, f"{profile_id}\n", mode=0o644)
    return True


def get_current_profile_id() -> str:
    if CURRENT_FILE.exists():
        try:
            val = CURRENT_FILE.read_text().strip()
            if val and PROFILE_ID_REGEX.match(val):
                return val
        except Exception:
            pass
    return "1"


def auto_onboard_profile_1():
    """Ensure existing active credentials are saved as Profile 1 if uninitialized."""
    p1_token = PROFILES_DIR / "1" / "token.json"
    if not p1_token.exists():
        raw = get_active_token()
        if is_valid_token(raw):
            get_profile_dir("1")
            write_file_atomic(p1_token, raw, mode=0o600)
            email = extract_email_from_token(raw)
            if email:
                save_profile_meta("1", email)
            if not CURRENT_FILE.exists():
                write_file_atomic(CURRENT_FILE, "1\n", mode=0o644)


def cmd_switch(target_id: str):
    try:
        tid = validate_profile_id(target_id)
    except ValueError as e:
        print(f"{RED}{e}{RESET}")
        return

    if not get_profile_token(tid):
        print(f"\n{RED}Profile [{tid}] is not configured yet.{RESET}")
        print(f"Run {BOLD}agy-switch login {tid}{RESET} to authenticate with this account.\n")
        return

    current_id = get_current_profile_id()
    if current_id == tid and is_valid_token(get_keyring_token()) and CLI_TOKEN_FILE.exists():
        email = get_profile_email(tid)
        tag = f" ({email})" if email else ""
        print(f"{YELLOW}Already using Profile [{tid}]{tag}.{RESET}")
        return

    # Snapshot currently active credentials first (preserves any refreshed tokens from agy)
    save_active_to_profile(current_id, fetch_email=False)

    # Apply target profile
    if apply_profile(tid):
        email = get_profile_email(tid)
        tag = f" ({BOLD}{email}{RESET}{GREEN})" if email else ""
        print(f"{GREEN}✔ Switched to Profile [{tid}]{tag}{RESET}")


def cmd_status():
    current_id = get_current_profile_id()
    print(f"\n{BOLD}Antigravity CLI Profiles:{RESET}")

    known = {"1", "2", "3"}
    if PROFILES_DIR.exists():
        for item in PROFILES_DIR.iterdir():
            if item.is_dir() and PROFILE_ID_REGEX.match(item.name) and (item / "token.json").exists():
                known.add(item.name)

    def sort_key(k: str):
        return (0, int(k)) if k.isdigit() else (1, k)

    for pid in sorted(known, key=sort_key):
        has_token = bool(get_profile_token(pid))
        is_active = (pid == current_id)
        email = get_profile_email(pid) if has_token else ""

        marker = f"{GREEN}● [{pid}]{RESET}" if is_active else f"  [{pid}]"
        label = (
            f"{BOLD}{email}{RESET}"
            if email
            else (f"Profile {pid}" if has_token else f"{DIM}(Not configured){RESET}")
        )
        status = f" {GREEN}(Active){RESET}" if is_active else ""
        print(f"  {marker} {label}{status}")
    print()


def cmd_whoami():
    cid = get_current_profile_id()
    email = get_profile_email(cid)
    if email:
        print(f"Active: Profile [{cid}] {email}")
    else:
        print(f"Active: Profile [{cid}]")


def cmd_login(profile_id: str):
    try:
        pid = validate_profile_id(profile_id)
    except ValueError as e:
        print(f"{RED}{e}{RESET}")
        return

    if not shutil.which("agy"):
        print(f"{RED}Error: 'agy' binary not found in PATH.{RESET}")
        return

    current_id = get_current_profile_id()
    # Save currently active session first
    save_active_to_profile(current_id, fetch_email=False)

    # Backup states for restoration in case login is cancelled in middle
    backup_current_id = current_id
    backup_active_token = get_active_token()
    backup_target_token = get_profile_token(pid)
    backup_target_email = get_profile_email(pid)

    if backup_target_token:
        cur_desc = f" ({backup_target_email})" if backup_target_email else ""
        print(f"{YELLOW}Profile [{pid}]{cur_desc} is currently configured.{RESET}")
        print(f"Logging in will {BOLD}overwrite{RESET} Profile [{pid}] unless cancelled.")

    print(f"\nPreparing login for Profile [{pid}]...")
    # Clear active credentials from BOTH keyring and CLI fallback token file
    # This ensures agy MUST open the browser rather than reusing any cached account
    clear_active_tokens()

    login_completed = False
    try:
        print(f"{YELLOW}{BOLD}A browser window will open for Google Sign-In.{RESET}")
        print(f"Sign into your target Google account (with Antigravity Pro).\n")
        input(f"Press {BOLD}[Enter]{RESET} to start...")
        subprocess.run(["agy"], check=False)
        login_completed = True
    except (KeyboardInterrupt, EOFError):
        print(f"\n{YELLOW}Login cancelled by user.{RESET}")
    except Exception as e:
        print(f"\n{RED}Error during login: {e}{RESET}")
    finally:
        new_token = get_active_token()
        # Verify login completed and produced valid new credentials
        if login_completed and is_valid_token(new_token):
            # Overwrite target profile
            p_dir = get_profile_dir(pid)
            write_file_atomic(p_dir / "token.json", new_token, mode=0o600)
            email = extract_email_from_token(new_token)
            save_profile_meta(pid, email)
            apply_profile(pid)
            tag = f" ({BOLD}{email}{RESET})" if email else ""
            print(f"\n{GREEN}{BOLD}✔ Profile [{pid}] successfully configured{tag}!{RESET}")
        else:
            print(f"\n{YELLOW}Login incomplete or cancelled. Restoring previous state...{RESET}")
            # Restore target profile if it previously existed
            if backup_target_token:
                p_dir = get_profile_dir(pid)
                write_file_atomic(p_dir / "token.json", backup_target_token, mode=0o600)
                if backup_target_email:
                    save_profile_meta(pid, backup_target_email)
            # Restore active session
            if backup_active_token:
                set_keyring_token(backup_active_token)
                write_file_atomic(CLI_TOKEN_FILE, backup_active_token, mode=0o600)
                write_file_atomic(CURRENT_FILE, f"{backup_current_id}\n", mode=0o644)


def main():
    PROFILES_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    auto_onboard_profile_1()

    if len(sys.argv) == 1:
        print(f"{RED}Error: Account parameter required (e.g. 'agy-switch 1', 'agy-switch 2', 'agy-switch 3').{RESET}")
        print(f"Usage: {BOLD}agy-switch <1|2|3>{RESET} (or 'status', 'whoami', 'login <id>')")
        sys.exit(1)

    arg = sys.argv[1].lower()
    if arg in ("-s", "--status", "status", "list", "ls"):
        cmd_status()
    elif arg in ("whoami", "current", "me"):
        cmd_whoami()
    elif arg in ("login", "setup", "add", "init"):
        if len(sys.argv) > 2:
            target = sys.argv[2]
            cmd_login(target)
        else:
            print(f"{RED}Error: Profile ID required for login.{RESET}")
            print(f"Usage: {BOLD}agy-switch login <1|2|3>{RESET}")
            sys.exit(1)
    elif arg in ("-h", "--help", "help"):
        print(f"""{BOLD}agy-switch{RESET} — Fast Account Switcher for Antigravity CLI

{BOLD}USAGE:{RESET}
  agy-switch <id>        Switch to Profile <id> (e.g. 1, 2, 3)
  agy-switch status, -s  Show profile status
  agy-switch whoami      Show active account
  agy-switch login <id>  Log into Profile <id> via browser OAuth
""")
    elif PROFILE_ID_REGEX.match(arg):
        cmd_switch(arg)
    else:
        print(f"{RED}Unknown argument: {arg}. Use 'agy-switch --help'{RESET}")
        sys.exit(1)


if __name__ == "__main__":
    main()
