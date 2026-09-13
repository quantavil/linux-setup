# agy-switch 2 — Rust account manager

Recoverable account switching for the Antigravity CLI on Linux. The Rust binary replaces the earlier Python script; `legacy/agy-switch.py` is retained only for reference.

## Install

Requires Rust/Cargo to build and a working persistent Secret Service provider (GNOME Keyring on this desktop). The binary uses D-Bus directly; it does not shell out to `secret-tool`. SQLite is bundled in the executable.

```sh
./apply_agy-switch.sh
```

The installer runs tests, builds with `Cargo.lock`, backs up the existing command and profiles, and atomically installs `~/.local/bin/agy-switch`. This makes it available across projects for your user, following the repository installation convention. It does not install an account-specific credential manager for other users.

## Commands

```sh
agy-switch 1                 # also: agy-switch switch 1
agy-switch status
agy-switch whoami
agy-switch login 3
agy-switch recover
agy-switch doctor
agy-switch migrate           # verify persistent keyring copies of saved profiles
```

Close running `agy` sessions before switching, logging in, or recovering. They can otherwise write refreshed credentials over a switch. The manager checks your running processes and refuses account changes while `agy` is running. Another program starting `agy` concurrently cannot be completely prevented; this is not a global lock inside the upstream CLI.

During login, sign in through the ordinary agy browser flow. The manager monitors credentials and saves the profile as soon as it observes refreshable credentials; exit agy to complete activation. A cancellation restores the previous state when possible. If authentication was already captured, it remains saved even if activation fails. `recover` completes pending work.

Status distinguishes saved profiles from verified active accounts. The legacy `current` marker alone is never proof of identity. No missing profile is automatically invented. A saved profile whose local file is missing can be restored from its persistent keyring copy when switching to it.

## Storage and recovery

`~/.gemini/profiles/` is private (0700):

- `<id>/token.json`: durable credential backup (0600), compatible with the old tool.
- `<id>/token.previous.json`: previous credential version when replaced.
- `state.sqlite3`: transactional profile identity metadata and selected profile; no OAuth secrets in SQLite.
- `pending.json`: temporary recovery record containing previous active credentials (0600).
- `.lock`: OS file lock shared by manager commands, automatically released on process exit.
- `current`: compatibility marker written after verified activation.

Existing profile files are imported without rewriting their token contents. Their permissions are tightened. Corrupt files are retained and reported. Identity is decoded locally from the saved ID token for account routing, not used as proof of server-side authentication or subscription status. OAuth expiry/revocation can still require reauthentication.

Each activated profile also receives a separate persistent Secret Service item with attributes `application=agy-switch, profile=<id>`. The CLI active item uses `service=gemini, username=antigravity` in the exact default collection. Session collections and ambiguous duplicate active items are rejected. Unlock prompts are handled by the Secret Service library. D-Bus method calls have a 10-second deadline; interactive unlock prompts wait for the user.

**Credential backups and recovery files contain plaintext OAuth secrets protected by file permissions, not encryption.** This preserves the existing storage model and enables recovery when the keyring is unavailable. The keyring provider determines its own at-rest encryption; a passwordless collection is not encrypted. Backups under `~/.local/state/agy-switch/backups/` have the same sensitivity. The tool reduces accidental secret logging and clears owned token buffers on drop, but cannot promise that every library allocation is scrubbed.

Switch ordering:

1. Validate target, recover pending work, preserve refreshed credentials by account identity.
2. Flush a recovery record with the previous keyring, fallback file, and selected profile.
3. Save the per-profile keyring copy; replace the active item without clearing it first.
4. Read back the keyring credential; atomically replace and verify the CLI fallback file.
5. Verify the keyring again, commit selection, and remove the recovery record.

On error, restore the recorded previous state. If restoration also fails, retain the journal and return a nonzero exit code. After interruption, recovery rolls an incomplete switch back; a captured login is completed. SQLite transactions cannot span D-Bus and files, so the journal is required. Files use private temporary files, fsync, rename, and directory fsync.

JSON is compacted before keyring writes. This avoids multiline credential values implicated in the previous GNOME Keyring 50 file-parsing failure. The manager never automatically resets a keyring or deletes unrelated credentials.

## Validation

```sh
cargo test --locked
cargo clippy --locked --all-targets -- -D warnings
cargo fmt --check
bash tests/keyring-restart.sh
```

The unit tests inject failed writes, persistent outages, ignored backend writes, interrupted operations, cancelled login, stale markers, invalid files, and lock contention. The integration script uses synthetic accounts, a disposable XDG data directory, and a private D-Bus. It checks active and saved credentials across two real GNOME Keyring daemon restarts, verifies service PIDs change, and restores a missing profile backup. It requires `dbus-run-session`, `busctl`, and `gnome-keyring-daemon`. It does not reboot the computer or authenticate real Google accounts.

Validated on 2026-09-13: 18 unit tests passed, formatting and Clippy checks passed, and the isolated integration test passed across two daemon restarts. After installation, a live Profile 1 → Profile 2 → Profile 1 round trip verified the active keyring identity, fallback file, selection marker, and absence of pending recovery. The running-process guard was also verified to reject a switch without changing the active marker or fallback credential. A full computer reboot and a new browser OAuth login were not part of this validation.

## Troubleshooting

`agy-switch doctor` reports unavailable/locked keyrings, invalid credentials, missing refresh tokens, running agy sessions, and pending recovery. It does not print tokens or repair the system silently.

If the default alias is listed but its collection returns “Object does not exist”, preserve keyring files before investigating the Secret Service daemon. A service restart may restore its exported objects, but this is an operating-system repair, not a reason to delete saved profiles or log in again.

A missing Profile 3 means no usable saved credentials were found for that ID. The Rust migration cannot reconstruct an account whose credentials were never durably captured. Run `agy-switch login 3` once in that case.

## Uninstall

`./revert_agy-switch.sh` removes only the installed command. Profiles, pending recovery, keyring items, and backups are retained. Installation backups include the previous executable if you need a manual rollback; finish pending Rust recovery before using the old script.
