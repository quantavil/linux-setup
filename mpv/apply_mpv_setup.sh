#!/bin/bash
# MPV material-osc + thumbfast Setup Script
set -euo pipefail

echo "========================================="
echo "  MPV material-osc + thumbfast Setup"
echo "========================================="
echo ""

# --- 1. Prerequisite checks ---
echo "[1/5] Checking prerequisites..."
for cmd in curl unzip mpv; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' is not installed. Please install it first." >&2
        exit 1
    fi
done
echo "Prerequisites met."

# --- 2. Clean up old uosc remnants ---
echo "[2/5] Cleaning up any old uosc remnants..."
if command -v pacman &>/dev/null && pacman -Qi mpv-uosc &>/dev/null; then
    echo "Found AUR package mpv-uosc. Removing it..."
    sudo pacman -Rns --noconfirm mpv-uosc
fi

rm -rf ~/.config/mpv/scripts/uosc
rm -f ~/.config/mpv/script-opts/uosc.conf
rm -f ~/.config/mpv/fonts/uosc_icons.otf

if [ -f ~/.config/mpv/input.conf ]; then
    echo "Cleaning up uosc bindings from input.conf..."
    sed -i '/uosc/d' ~/.config/mpv/input.conf
    # Remove file if it is empty or contains only comments/whitespace
    if [ ! -s ~/.config/mpv/input.conf ] || ! grep -q '[^[:space:]#]' ~/.config/mpv/input.conf; then
        rm -f ~/.config/mpv/input.conf
        echo "Removed empty input.conf."
    fi
fi

# --- 3. Create config directories ---
echo "[3/5] Creating mpv config directories..."
mkdir -p ~/.config/mpv/scripts ~/.config/mpv/fonts

# --- 4. Install material-osc & thumbfast ---
echo "[4/5] Fetching and installing material-osc & thumbfast..."
LATEST_ZIP_URL=$(curl -s https://api.github.com/repos/brahmkshatriya/material-osc/releases/latest | grep "browser_download_url" | cut -d '"' -f 4 || true)

if [ -z "$LATEST_ZIP_URL" ]; then
    LATEST_ZIP_URL="https://github.com/brahmkshatriya/material-osc/releases/latest/download/material-osc.zip"
fi

echo "Downloading material-osc from $LATEST_ZIP_URL..."
TMP_ZIP=$(mktemp /tmp/material-osc-XXXXXX.zip)
trap 'rm -f "$TMP_ZIP"' EXIT
curl -fsSL "$LATEST_ZIP_URL" -o "$TMP_ZIP"
unzip -o "$TMP_ZIP" -d ~/.config/mpv/
rm -f "$TMP_ZIP"
trap - EXIT

echo "Downloading thumbfast..."
curl -fsSL https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.lua -o ~/.config/mpv/scripts/thumbfast.lua

# --- 5. Configure mpv.conf ---
echo "[5/5] Writing mpv.conf..."
cat <<'EOF' > ~/.config/mpv/mpv.conf
# Recommended settings for material-osc
video-sync=display-resample
force-window=yes

# Disable default OSC to avoid overlap with material-osc
osc=no
EOF

echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
