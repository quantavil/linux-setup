#!/bin/bash
# Tauri / WebKitGTK Lag Fix — Revert
# Restores the stock WebKitGTK renderer choice and KWin settings.

set -euo pipefail

echo "Reverting Tauri/WebKitGTK lag fix..."

# 1. Drop the env override (apps fall back to their hardcoded =1)
echo "[1/3] Removing ~/.config/environment.d/webkit.conf..."
rm -f ~/.config/environment.d/webkit.conf
echo "       done."

# 2. Restore kwinrc from backup, or undo the two keys by hand
echo "[2/3] Restoring KWin config..."
if [ -f ~/.config/kwinrc.bak ]; then
    cp ~/.config/kwinrc.bak ~/.config/kwinrc
    echo "       restored from ~/.config/kwinrc.bak"
elif command -v kwriteconfig6 &>/dev/null; then
    kwriteconfig6 --file kwinrc --group Plugins --key wobblywindowsEnabled true
    kwriteconfig6 --file kwinrc --group Compositing --key LatencyPolicy --delete
    echo "       no backup found; undid the two keys directly."
else
    echo "       WARNING: no backup and no kwriteconfig6, nothing to undo."
fi

# 3. Reload KWin
echo "[3/3] Reloading KWin..."
if qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null \
   || qdbus org.kde.KWin /KWin reconfigure 2>/dev/null; then
    echo "       KWin reconfigured."
else
    echo "       WARNING: could not reach KWin over D-Bus (not a KDE session?)."
fi

echo
echo "Done. Log out and back in to clear the env var from the session."
