#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONT_DIR="$HOME/.local/share/fonts/ms-fonts"

echo "=== Microsoft Fonts Revert Script ==="
echo ""

# Check if font directory exists
if [ ! -d "$FONT_DIR" ]; then
    echo "No Microsoft fonts directory found at $FONT_DIR"
    echo "Nothing to revert."
    exit 0
fi

# Count fonts before removal
FONT_COUNT=$(find "$FONT_DIR" -type f \( -iname "*.ttf" -o -iname "*.ttc" -o -iname "*.otf" \) 2>/dev/null | wc -l)
echo "Found $FONT_COUNT fonts in $FONT_DIR"

# Prompt for confirmation unless -y / --yes passed
CONFIRM=""
if [[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]]; then
    CONFIRM="y"
else
    echo ""
    read -rp "Are you sure you want to remove all Microsoft fonts? (y/N): " CONFIRM
fi

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborting revert."
    exit 0
fi

# Remove all fonts
echo "Removing fonts from $FONT_DIR..."
rm -rf "$FONT_DIR"
echo "✓ Fonts removed."

# Rebuild font cache
echo "Rebuilding font cache..."
fc-cache -f
echo "✓ Font cache rebuilt."

# Clean up font directory if empty
rmdir "$HOME/.local/share/fonts" 2>/dev/null || true

echo ""
echo "=== Revert Complete ==="
echo ""
echo "Microsoft fonts have been removed from your system."
echo ""
