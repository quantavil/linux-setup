#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONT_REPO="https://github.com/quantavil/windows-11-fonts.git"
FONT_DIR="$HOME/.local/share/fonts/ms-fonts"

echo "=== Microsoft Fonts Setup Script ==="
echo ""

# Check for git
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed. Please install git first." >&2
    exit 1
fi

# Check for fc-cache
if ! command -v fc-cache &> /dev/null; then
    echo "Error: fc-cache (fontconfig) is not installed. Please install fontconfig first." >&2
    exit 1
fi

# Clone repo (shallow clone to save bandwidth & disk)
TMP_DIR=$(mktemp -d -t windows-11-fonts-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Cloning Windows 11 fonts repository (shallow)..."
git clone --depth 1 "$FONT_REPO" "$TMP_DIR"
echo "✓ Repository cloned."

# Create folder for Windows fonts
echo "Creating font directory..."
mkdir -p "$FONT_DIR"
echo "✓ Font directory created at $FONT_DIR"

# Copy TTF, TTC, and OTF fonts, skip if already exists
echo "Copying fonts (TTF, TTC, OTF, skipping existing)..."
FONT_COUNT=0
SKIPPED_COUNT=0

while IFS= read -r -d '' font; do
    FONT_NAME=$(basename "$font")
    if [ ! -f "$FONT_DIR/$FONT_NAME" ]; then
        cp "$font" "$FONT_DIR/"
        FONT_COUNT=$((FONT_COUNT + 1))
    else
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
done < <(find "$TMP_DIR" -type f \( -iname "*.ttf" -o -iname "*.ttc" -o -iname "*.otf" \) -print0)

echo "✓ Copied $FONT_COUNT new fonts (skipped $SKIPPED_COUNT existing fonts)."

# Rebuild font cache
echo "Rebuilding font cache..."
fc-cache -f
echo "✓ Font cache rebuilt."

# Verify installation of common fonts
echo ""
echo "Verifying installation of common fonts..."
if fc-list : family | grep -E -i "Arial|Times|Verdana|Courier|Cambria" > /dev/null; then
    echo "✓ Common Microsoft fonts found in system."
else
    echo "⚠ Warning: Some common fonts may not be installed correctly."
fi

# Cleanup
echo "Cleaning up temporary files..."
rm -rf "$TMP_DIR"
trap - EXIT
echo "✓ Temporary files removed."

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Microsoft fonts have been installed to: $FONT_DIR"
echo ""
echo "To verify installation, run:"
echo "  fc-list : family | grep -E -i \"Arial|Times|Verdana|Courier|Cambria\""
echo ""
