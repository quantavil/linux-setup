#!/bin/bash
# Revert MPV material-osc + thumbfast Setup
set -euo pipefail

echo "========================================="
echo "  Reverting MPV material-osc + thumbfast Setup"
echo "========================================="
echo ""

echo "[1/3] Removing material-osc files and fonts..."
rm -f ~/.config/mpv/scripts/material-osc.lua
rm -rf ~/.config/mpv/scripts/material-osc/
rm -f ~/.config/mpv/fonts/material-osc_icons.otf
rm -f ~/.config/mpv/fonts/material-osc_google_sans_flex.ttf

echo "[2/3] Removing thumbfast..."
rm -f ~/.config/mpv/scripts/thumbfast.lua

echo "[3/3] Removing mpv.conf..."
rm -f ~/.config/mpv/mpv.conf

# Clean up directories if they are empty
rmdir ~/.config/mpv/fonts 2>/dev/null || true
rmdir ~/.config/mpv/scripts 2>/dev/null || true
rmdir ~/.config/mpv 2>/dev/null || true

echo ""
echo "========================================="
echo "  Revert Complete!"
echo "========================================="
