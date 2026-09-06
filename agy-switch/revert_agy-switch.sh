#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# Antigravity CLI Account Switcher — Uninstallation Script
# ══════════════════════════════════════════════════════════════════
set -euo pipefail

echo "Uninstalling agy-switch..."

rm -f "$HOME/.local/bin/agy-switch"
echo "✓ Removed ~/.local/bin/agy-switch"

PROFILES_DIR="$HOME/.gemini/profiles"
if [[ -d "$PROFILES_DIR" ]]; then
    read -p "Do you want to delete profile storage under $PROFILES_DIR? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$PROFILES_DIR"
        echo "✓ Profile storage deleted."
    fi
fi

echo "Uninstallation complete."
