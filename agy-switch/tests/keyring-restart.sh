#!/usr/bin/env bash
# Uses synthetic credentials, a private bus, and disposable keyring storage.
set -euo pipefail
if [[ "${1:-}" != --inside ]]; then
  project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  cd "$project_dir"
  test_root="$(mktemp -d /tmp/agy-switch-keyring-test.XXXXXX)"
  trap 'rm -rf -- "$test_root"' EXIT
  touch "$test_root/isolated-test-marker"
  mkdir -p "$test_root/data" "$test_root/run"
  export AGY_SWITCH_TEST_ROOT="$test_root"
  export XDG_DATA_HOME="$test_root/data"
  export XDG_RUNTIME_DIR="$test_root/run"
  # No host service directories: a readiness probe must not auto-start the
  # distribution daemon and race the candidate binary on this private bus.
  cat > "$test_root/bus.conf" <<'BUS'
<busconfig>
  <type>session</type>
  <listen>unix:tmpdir=/tmp</listen>
  <policy context="default">
    <allow send_destination="*"/>
    <allow receive_sender="*"/>
    <allow own="*"/>
  </policy>
</busconfig>
BUS
  exec_status=0
  dbus-run-session --config-file "$test_root/bus.conf" -- bash "$project_dir/tests/keyring-restart.sh" --inside || exec_status=$?
  exit "$exec_status"
fi
daemon_pid=
owner_pid=
previous_owner=
trap 'for pid in "$owner_pid" "$daemon_pid"; do if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; fi; done' EXIT
for phase in seed restart verify; do
  candidate="${AGY_SWITCH_TEST_DAEMON:-/usr/bin/gnome-keyring-daemon}"
  if [[ "$phase" == seed && "${AGY_SWITCH_TEST_REPAIR:-0}" == 1 ]]; then
    candidate=/usr/bin/gnome-keyring-daemon
  fi
  # NUL supplies an empty C-string password; EOF means no password supplied.
  # A newline is a one-byte password and selects the encrypted format instead.
  "$candidate" --foreground --components=secrets --unlock < <(printf '\0') >"$AGY_SWITCH_TEST_ROOT/daemon.log" 2>&1 &
  daemon_pid=$!
  ready=false
  for attempt in {1..50}; do
    if busctl --user --auto-start=no get-property org.freedesktop.secrets /org/freedesktop/secrets/aliases/default org.freedesktop.Secret.Collection Locked 2>/dev/null | grep -q 'b false'; then
      ready=true
      break
    fi
    sleep 0.1
  done
  if [[ "$ready" != true ]]; then echo 'Private test keyring failed to start' >&2; cat "$AGY_SWITCH_TEST_ROOT/daemon.log"; exit 1; fi
  read -r _ owner_pid < <(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s org.freedesktop.secrets)
  if [[ "$(readlink -f "/proc/$owner_pid/exe")" != "$(readlink -f "$candidate")" ]]; then
    echo 'Unexpected daemon owns the private test bus' >&2; exit 1
  fi
  if [[ "$owner_pid" == "$previous_owner" ]]; then echo 'Test daemon did not restart' >&2; exit 1; fi
  echo "Isolated keyring phase $phase: service PID $owner_pid"
  AGY_SWITCH_TEST_PHASE="$phase" cargo test --locked real_keyring_restart -- --ignored --nocapture
  python - <<'PY'
import os
from pathlib import Path
files = list((Path(os.environ['XDG_DATA_HOME']) / 'keyrings').glob('*.keyring'))
assert files and all(p.read_bytes().startswith(b'[keyring]\n') for p in files), 'Test must exercise unencrypted keyrings'
PY
  kill "$owner_pid"
  if [[ "$owner_pid" != "$daemon_pid" ]]; then kill "$daemon_pid" 2>/dev/null || true; fi
  wait "$daemon_pid" || true
  if [[ "$phase" == seed && "${AGY_SWITCH_TEST_REPAIR:-0}" == 1 ]]; then
    for keyring in "$XDG_DATA_HOME"/keyrings/*.keyring; do
      python keyring-fix/repair_unescaped.py "$keyring"
    done
  fi
  previous_owner="$owner_pid"
  owner_pid=
  daemon_pid=
done
echo 'OAuth profiles and another application’s multiline secret survived two daemon restarts.'
