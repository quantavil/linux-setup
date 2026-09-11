#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# Antigravity CLI Account Switcher — Setup & Installation Script
# ══════════════════════════════════════════════════════════════════
set -euo pipefail

echo "Installing Antigravity CLI Switcher (agy-switch)..."

# 1. Dependency checks
if ! command -v python3 &>/dev/null; then
    echo "Error: 'python3' is required but not found in PATH." >&2
    exit 1
fi

if ! command -v secret-tool &>/dev/null; then
    echo "Warning: 'secret-tool' (libsecret) not found." >&2
    echo "Install via: sudo pacman -S libsecret" >&2
fi

if ! command -v agy &>/dev/null; then
    echo "Warning: 'agy' binary not found in PATH." >&2
fi

# 2. Install binary to ~/.local/bin
TARGET_DIR="$HOME/.local/bin"
mkdir -p "$TARGET_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/agy-switch" "$TARGET_DIR/agy-switch"
chmod +x "$TARGET_DIR/agy-switch"

echo ""
echo "✓ Successfully installed 'agy-switch' to $TARGET_DIR/agy-switch"
echo ""
echo "Make sure $TARGET_DIR is in your PATH."
echo "Run 'agy-switch status' to inspect configured profiles."
echo "Run 'agy-switch login 2' or 'agy-switch login 3' to onboard additional accounts."
echo "Run 'agy-switch <1|2|3>' to switch between accounts."
