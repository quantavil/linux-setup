#!/usr/bin/env bash
# strata: Build and install latest Strata package
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

makepkg -f
pkg_file=$(ls -t strata-*.pkg.tar.zst | grep -v 'debug' | head -n 1)
pkexec pacman -U --noconfirm "$pkg_file"
