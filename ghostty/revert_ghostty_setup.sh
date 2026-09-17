#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GHOSTTY_DIR="$HOME/.config/ghostty"
FISH_DIR="$HOME/.config/fish"
NAVI_CHEATS_DIR="$HOME/.local/share/navi/cheats"
BASHRC="$HOME/.bashrc"

echo "=== Ghostty + Shell Revert Script ==="
echo ""

CONFIRM=""
if [[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]]; then
    CONFIRM="y"
else
    read -rp "Are you sure you want to revert Ghostty, Fish, Bash, and Navi cheatsheet configs? (y/N): " CONFIRM
fi

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborting revert."
    exit 0
fi

# Revert Ghostty config
LATEST_GHOSTTY_BAK=$(find "$GHOSTTY_DIR" -name "config.bak_*" 2>/dev/null | sort | tail -n 1)
if [ -n "$LATEST_GHOSTTY_BAK" ] && [ -f "$LATEST_GHOSTTY_BAK" ]; then
    echo "Restoring Ghostty config from $LATEST_GHOSTTY_BAK..."
    cp "$LATEST_GHOSTTY_BAK" "$GHOSTTY_DIR/config"
    echo "✓ Ghostty config restored."
fi

# Revert Fish config
LATEST_FISH_BAK=$(find "$FISH_DIR" -name "config.fish.bak_*" 2>/dev/null | sort | tail -n 1)
if [ -n "$LATEST_FISH_BAK" ] && [ -f "$LATEST_FISH_BAK" ]; then
    echo "Restoring Fish config from $LATEST_FISH_BAK..."
    cp "$LATEST_FISH_BAK" "$FISH_DIR/config.fish"
    echo "✓ Fish config restored."
fi

# Revert Bash config
LATEST_BASH_BAK=$(find "$HOME" -maxdepth 1 -name ".bashrc.bak_*" 2>/dev/null | sort | tail -n 1)
if [ -n "$LATEST_BASH_BAK" ] && [ -f "$LATEST_BASH_BAK" ]; then
    echo "Restoring ~/.bashrc from $LATEST_BASH_BAK..."
    cp "$LATEST_BASH_BAK" "$BASHRC"
    echo "✓ ~/.bashrc restored."
fi

# Remove installed cheats
if [ -d "$NAVI_CHEATS_DIR" ]; then
    echo "Removing installed cheatsheets..."
    rm -f "$NAVI_CHEATS_DIR/personal.cheat"
    echo "✓ Removed personal.cheat."
fi

# Revert Navi config
NAVI_CONFIG_DIR="$HOME/.config/navi"
LATEST_NAVI_BAK=$(find "$NAVI_CONFIG_DIR" -name "config.yaml.bak_*" 2>/dev/null | sort | tail -n 1)
if [ -n "$LATEST_NAVI_BAK" ] && [ -f "$LATEST_NAVI_BAK" ]; then
    echo "Restoring Navi config from $LATEST_NAVI_BAK..."
    cp "$LATEST_NAVI_BAK" "$NAVI_CONFIG_DIR/config.yaml"
    echo "✓ Navi config restored."
else
    rm -f "$NAVI_CONFIG_DIR/config.yaml"
fi

echo ""
echo "=== Revert Complete ==="
echo ""
