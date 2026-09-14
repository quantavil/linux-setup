#!/usr/bin/env bash
# Remove only this module's activation overrides; retain credentials/backups.
set -euo pipefail
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
if pgrep -u "$UID" -x agy >/dev/null; then
  echo 'Exit agy before changing the keyring service.' >&2; exit 1
fi
paths=(
  "$config_dir/systemd/user/gnome-keyring-daemon.service.d/agy-switch-textual-fix.conf"
  "$data_dir/dbus-1/services/org.freedesktop.secrets.service"
  "$data_dir/dbus-1/services/org.gnome.keyring.service"
  "$data_dir/dbus-1/services/org.freedesktop.impl.portal.Secret.service"
)
for path in "${paths[@]}"; do
  if [[ -e "$path" ]] && ! grep -q '^# Managed by linux-setup/agy-switch/apply_keyring-fix.sh$' "$path"; then
    echo 'An activation override is not managed by this module; refusing to remove it.' >&2; exit 1
  fi
done
for path in "${paths[@]}"; do rm -f -- "$path"; done
systemctl --user daemon-reload
systemctl --user restart gnome-keyring-daemon.service
echo 'Distribution daemon restored. Credentials, patched binary, and private backups retained.'
echo 'If the distribution serializer is still affected, multiline saves can corrupt the keyring again.'
echo 'Any pre-existing user activation files are in ~/.local/state/agy-switch/keyring-fix/ backups.'
