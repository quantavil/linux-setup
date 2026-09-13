#!/usr/bin/env bash
set -euo pipefail
umask 077
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_dir"
cargo test --locked
cargo build --release --locked
target_dir="$HOME/.local/bin"
backup_dir="$HOME/.local/state/agy-switch/backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$target_dir" "$backup_dir"
if [[ -e "$target_dir/agy-switch" ]]; then
  cp -p -- "$target_dir/agy-switch" "$backup_dir/agy-switch"
fi
if [[ -d "$HOME/.gemini/profiles" ]]; then
  cp -a -- "$HOME/.gemini/profiles" "$backup_dir/profiles"
  chmod -R go-rwx "$backup_dir/profiles"
fi
temporary_binary="$(mktemp "$target_dir/.agy-switch.XXXXXX")"
trap 'rm -f -- "$temporary_binary"' EXIT
install -m 755 target/release/agy-switch "$temporary_binary"
mv -f -- "$temporary_binary" "$target_dir/agy-switch"
"$target_dir/agy-switch" --version
if ! "$target_dir/agy-switch" migrate; then
  echo 'Installed; keyring copies pending. Run agy-switch migrate when the keyring is available.' >&2
fi
"$target_dir/agy-switch" status
echo "Installed for your account at $target_dir/agy-switch"
echo "Previous command and profiles backed up in $backup_dir"
