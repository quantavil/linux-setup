#!/bin/bash
# Tauri / WebKitGTK Lag Fix — Installer
# Re-enables the WebKitGTK DMA-BUF renderer and trims KWin compositing latency.
# User-level only, no sudo.

set -euo pipefail

echo "Applying Tauri/WebKitGTK lag fix..."

# 1. Re-enable the DMA-BUF renderer for all WebKitGTK apps
echo "[1/4] Writing ~/.config/environment.d/webkit.conf..."
mkdir -p ~/.config/environment.d
echo "WEBKIT_DISABLE_DMABUF_RENDERER=0" > ~/.config/environment.d/webkit.conf
echo "       done."

# 2. Back up kwinrc before touching it
echo "[2/4] Backing up ~/.config/kwinrc..."
if [ -f ~/.config/kwinrc ]; then
    cp ~/.config/kwinrc ~/.config/kwinrc.bak
    echo "       saved to ~/.config/kwinrc.bak"
else
    echo "       no kwinrc found, skipping backup."
fi

# 3. Disable wobbly windows, drop compositing latency
echo "[3/4] Tuning KWin..."
if command -v kwriteconfig6 &>/dev/null; then
    kwriteconfig6 --file kwinrc --group Plugins --key wobblywindowsEnabled false
    kwriteconfig6 --file kwinrc --group Compositing --key LatencyPolicy Low
    echo "       wobblywindows off, LatencyPolicy=Low"
else
    echo "       WARNING: kwriteconfig6 not found, skipping KWin tuning."
fi

# 4. Reload KWin so the changes apply without a logout
echo "[4/4] Reloading KWin..."
if qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null \
   || qdbus org.kde.KWin /KWin reconfigure 2>/dev/null; then
    echo "       KWin reconfigured."
else
    echo "       WARNING: could not reach KWin over D-Bus (not a KDE session?)."
fi

echo
echo "Done. LOG OUT AND BACK IN for the env var to reach apps launched from Plasma."
echo "Verify afterwards with:"
echo "  for p in \$(pgrep -f WebKitWebProcess); do tr '\\0' '\\n' < /proc/\$p/environ | grep DMABUF; done"
echo "Expect '=0'."
