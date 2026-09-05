#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# Groq AI — Setup & Installation Script
# ══════════════════════════════════════════════════════════════════
set -euo pipefail

echo "Installing Groq AI (CLI Assistant & Global Voice Typing)..."

# 1. Dependency checks
MISSING_CORE=""
for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING_CORE="$MISSING_CORE $cmd"
    fi
done

if [[ -n "$MISSING_CORE" ]]; then
    echo "Error: Missing required core dependencies:$MISSING_CORE" >&2
    echo "Please install them via: sudo pacman -S$MISSING_CORE" >&2
    exit 1
fi

MISSING_VOICE=""
for cmd in pw-record wl-copy notify-send opusenc wtype; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING_VOICE="$MISSING_VOICE $cmd"
    fi
done

if [[ -n "$MISSING_VOICE" ]]; then
    echo "Warning: Missing recommended tools for global voice typing:$MISSING_VOICE" >&2
    echo "Voice typing into browser/apps needs: sudo pacman -S pipewire-audio wl-clipboard libnotify opus-tools wtype" >&2
else
    echo "✓ All core and voice typing dependencies are installed."
fi

# 2. Install single binary to ~/.local/bin
TARGET_DIR="$HOME/.local/bin"
mkdir -p "$TARGET_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/ai" "$TARGET_DIR/ai"
chmod +x "$TARGET_DIR/ai"

# Remove legacy 'stt' symlink if present to keep only the single 'ai' command
rm -f "$TARGET_DIR/stt"

echo ""
echo "✓ Successfully installed 'ai' to $TARGET_DIR/ai"
echo ""
echo "Make sure $TARGET_DIR is in your PATH."
echo "Run 'ai --config' to configure your Groq API key."
echo ""
echo "Global Keyboard Shortcut Setup (Omarchy / Hyprland):"
echo "  Add the following line to ~/.config/hypr/bindings.lua:"
echo ""
echo "    o.bind(\"ALT + L\", \"Groq Voice Typing\", \"$TARGET_DIR/ai -v\")"
echo ""
echo "  Then reload Hyprland bindings with: hyprctl reload"
echo "  Now press Alt+L anywhere (e.g. in your browser) to voice type!"
