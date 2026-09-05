#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# Groq AI — Uninstallation Script
# ══════════════════════════════════════════════════════════════════
set -euo pipefail

echo "Uninstalling Groq AI..."

rm -f "$HOME/.local/bin/ai"
rm -f "$HOME/.local/bin/stt"
echo "✓ Removed ~/.local/bin/ai and ~/.local/bin/stt"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/groq-ai"
if [[ -d "$CONFIG_DIR" ]]; then
    read -p "Do you want to delete conversation history and configuration under $CONFIG_DIR? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$CONFIG_DIR"
        echo "✓ Configuration and history deleted."
    fi
fi

echo "Uninstallation complete."
