#!/usr/bin/env bash
# User-scoped GNOME Keyring 50 writer fix. No root files are replaced.
set -euo pipefail
umask 077
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repair=false
case "${1:-}" in
  '') ;;
  --repair-unescaped-default) repair=true ;;
  *) echo 'Usage: apply_keyring-fix.sh [--repair-unescaped-default]' >&2; exit 1 ;;
esac
if [[ "$repair" == true ]]; then
  running_pid="$(systemctl --user show --property MainPID --value gnome-keyring-daemon.service)"
  if [[ "$(readlink -f "/proc/$running_pid/exe" || true)" != /usr/bin/gnome-keyring-daemon ]]; then
    echo 'Raw-secret repair requires the known stock daemon; do not apply it to an already patched keyring.' >&2; exit 1
  fi
fi
if pgrep -u "$UID" -x agy >/dev/null; then
  echo 'Exit agy before repairing its shared keyring.' >&2; exit 1
fi
if [[ "$(gnome-keyring-daemon --version)" != *'50.0'* ]]; then
  echo 'This workaround is pinned to GNOME Keyring 50.0. Check the installed version first.' >&2; exit 1
fi
for unit in gnome-keyring-daemon.service gnome-keyring-daemon.socket; do
  if [[ "$(systemctl --user is-enabled "$unit" 2>/dev/null || true)" == masked* ]]; then
    echo 'Keyring unit already masked; refusing to change existing policy.' >&2; exit 1
  fi
done
python -c 'from gi.repository import GLib'
bash "$project_dir/keyring-fix/build.sh"
daemon="$project_dir/target/keyring-fix/build/daemon/gnome-keyring-daemon"
AGY_SWITCH_TEST_DAEMON="$daemon" bash "$project_dir/tests/keyring-restart.sh"
AGY_SWITCH_TEST_DAEMON="$daemon" AGY_SWITCH_TEST_REPAIR=1 bash "$project_dir/tests/keyring-restart.sh"
python "$project_dir/tests/test_keyring_repair.py"

data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
backup_dir="$HOME/.local/state/agy-switch/keyring-fix/$(date +%Y%m%d-%H%M%S)-$$"
install_dir="$HOME/.local/lib/agy-switch/gnome-keyring-50.0"
override="$config_dir/systemd/user/gnome-keyring-daemon.service.d/agy-switch-textual-fix.conf"
mkdir -p "$backup_dir" "$install_dir" "$(dirname -- "$override")" "$data_dir/dbus-1/services"
# Save the affected activation files too, including any previous user overrides.
for path in "$override" "$data_dir/dbus-1/services/org.freedesktop.secrets.service" \
  "$data_dir/dbus-1/services/org.gnome.keyring.service" \
  "$data_dir/dbus-1/services/org.freedesktop.impl.portal.Secret.service"; do
  if [[ -e "$path" ]]; then cp -a -- "$path" "$backup_dir/$(basename -- "$path")"; fi
done
if [[ -f "$install_dir/gnome-keyring-daemon" ]]; then
  cp -p -- "$install_dir/gnome-keyring-daemon" "$backup_dir/gnome-keyring-daemon"
fi
install -m 755 "$daemon" "$install_dir/.gnome-keyring-daemon.new"
mv -f -- "$install_dir/.gnome-keyring-daemon.new" "$install_dir/gnome-keyring-daemon"
cat > "$override" <<'UNIT'
# Managed by linux-setup/agy-switch/apply_keyring-fix.sh
[Service]
ExecStart=
ExecStart=%h/.local/lib/agy-switch/gnome-keyring-50.0/gnome-keyring-daemon --foreground --components=pkcs11,secrets --control-directory=%t/keyring
UNIT
python - "$data_dir/dbus-1/services" "$install_dir/gnome-keyring-daemon" <<'PY'
from pathlib import Path
import sys
directory, binary = sys.argv[1:]
if any(c in binary for c in '\n\r"\\'):
    raise SystemExit('Unsupported home path for D-Bus activation')
for name in ('org.freedesktop.secrets', 'org.gnome.keyring', 'org.freedesktop.impl.portal.Secret'):
    (Path(directory) / (name + '.service')).write_text(
        '# Managed by linux-setup/agy-switch/apply_keyring-fix.sh\n'
        f'[D-BUS Service]\nName={name}\n'
        f'Exec="{binary}" --start --foreground --components=pkcs11,secrets\n'
        'SystemdService=gnome-keyring-daemon.service\n')
PY
systemctl --user daemon-reload
# Block activation while copying/repairing on-disk credentials.
maintenance=false
cleanup() {
  if [[ "$maintenance" == true ]]; then
    systemctl --user unmask --runtime gnome-keyring-daemon.service gnome-keyring-daemon.socket
    systemctl --user start gnome-keyring-daemon.socket gnome-keyring-daemon.service
  fi
}
trap cleanup EXIT
maintenance=true
systemctl --user mask --runtime --now gnome-keyring-daemon.service gnome-keyring-daemon.socket
cp -a -- "$data_dir/keyrings" "$backup_dir/keyrings"
chmod -R go-rwx "$backup_dir"
if [[ "$repair" == true ]]; then
  # Only use for raw secret= values written by the stock 50.0 serializer.
  default_name="$(cat "$data_dir/keyrings/default")"
  if [[ ! "$default_name" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo 'Unexpected default keyring filename; backup retained.' >&2; exit 1
  fi
  python "$project_dir/keyring-fix/repair_unescaped.py" "$data_dir/keyrings/$default_name.keyring"
fi
cleanup
maintenance=false
ready=false
# Type=simple may report started before the child has executed the binary.
for attempt in {1..50}; do
  pid="$(systemctl --user show --property MainPID --value gnome-keyring-daemon.service)"
  if [[ "$(readlink -f "/proc/$pid/exe" || true)" == "$install_dir/gnome-keyring-daemon" ]]; then
    ready=true
    break
  fi
  sleep 0.1
done
if [[ "$ready" != true ]]; then
  echo 'Patched daemon did not become the running service.' >&2; exit 1
fi
echo "Installed the persistent user service and D-Bus activation overrides. Private backup: $backup_dir"
echo 'Run agy-switch recover, then agy-switch doctor. Unlock the keyring if prompted.'
