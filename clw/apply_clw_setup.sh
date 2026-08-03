#!/bin/bash
# clw — install the Claude Code scheduler fish function via symlink
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p ~/.config/fish/functions
ln -sf "$SCRIPT_DIR/clw.fish" ~/.config/fish/functions/clw.fish

echo "Linked clw.fish -> ~/.config/fish/functions/clw.fish"
echo "Run 'exec fish' or open a new terminal, then try: clw --help"
