#!/usr/bin/env bash
# Build only the patched daemon; distribution libraries and PAM stay installed.
set -euo pipefail
umask 077
fix_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
build_root="$fix_dir/../target/keyring-fix"
mkdir -p "$build_root"
for tool in cc pkg-config curl tar patch glib-genmarshal glib-mkenums gdbus-codegen; do
  command -v "$tool" >/dev/null || { echo "Missing $tool. Install the README build dependencies first." >&2; exit 1; }
done
if command -v meson >/dev/null; then
  meson_cmd=(meson)
else
  # An isolated build tool environment, without changing system Python.
  command -v uvx >/dev/null
  meson_cmd=(uvx --with ninja meson)
fi
archive="$build_root/gnome-keyring-50.0.tar.xz"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --proto '=https' --tlsv1.2 \
    https://download.gnome.org/sources/gnome-keyring/50/gnome-keyring-50.0.tar.xz -o "$archive"
fi
echo "cbd72062c53c9702bc2c4733991ad5f051ca682882b30905a2829bcf1a8ecc7c  $archive" | sha256sum --check
# Re-extract the pinned source on every build; do not patch an unknown checkout.
tar -xJf "$archive" -C "$build_root"
patch --batch -d "$build_root/gnome-keyring-50.0" -p1 < "$fix_dir/escape-textual-secrets.patch"
# Honor build tools on PATH even when distro pkg-config hardcodes /usr/bin.
python - "$build_root/native.ini" <<'PY'
import pathlib, shutil, sys
text = '[binaries]\n'
for name in ('glib-genmarshal', 'glib-mkenums', 'gdbus-codegen'):
    text += f'{name} = {shutil.which(name)!r}\n'
pathlib.Path(sys.argv[1]).write_text(text)
PY
setup_args=()
[[ ! -f "$build_root/build/meson-private/coredata.dat" ]] || setup_args+=(--wipe)
"${meson_cmd[@]}" setup "${setup_args[@]}" "$build_root/build" "$build_root/gnome-keyring-50.0" \
  --native-file "$build_root/native.ini" --prefix=/usr --buildtype=release \
  -Dpam=false -Dmanpage=false -Ddebug-mode=false
"${meson_cmd[@]}" compile -C "$build_root/build" gnome-keyring-daemon -j "${BUILD_JOBS:-2}"
echo "Built: $build_root/build/daemon/gnome-keyring-daemon"
