#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

echo "=== Ghostty, Fish, Bash & Navi Setup Installer ==="
echo ""

# Check dependencies
echo "Checking installed tools..."
for cmd in ghostty fish navi fzf shelly eza bat zoxide yazi; do
    if command -v "$cmd" &>/dev/null; then
        echo "  ✓ $cmd"
    else
        echo "  ⚠ $cmd is not found in PATH"
    fi
done
echo ""

# 1. Setup Ghostty Config
GHOSTTY_DIR="$HOME/.config/ghostty"
mkdir -p "$GHOSTTY_DIR"

if [ -f "$GHOSTTY_DIR/config" ]; then
    echo "Backing up existing Ghostty config to $GHOSTTY_DIR/config.bak_$TIMESTAMP..."
    cp "$GHOSTTY_DIR/config" "$GHOSTTY_DIR/config.bak_$TIMESTAMP"
fi
echo "Installing Ghostty config..."
cp "$SCRIPT_DIR/config" "$GHOSTTY_DIR/config"
echo "✓ Ghostty config installed."

# 2. Setup Fish Config
FISH_DIR="$HOME/.config/fish"
mkdir -p "$FISH_DIR"

if [ -f "$FISH_DIR/config.fish" ]; then
    echo "Backing up existing Fish config to $FISH_DIR/config.fish.bak_$TIMESTAMP..."
    cp "$FISH_DIR/config.fish" "$FISH_DIR/config.fish.bak_$TIMESTAMP"
fi
echo "Installing Fish config..."
cp "$SCRIPT_DIR/config.fish" "$FISH_DIR/config.fish"
echo "✓ Fish config installed."

# 3. Setup Navi Cheatsheets
NAVI_CHEATS_DIR="$HOME/.local/share/navi/cheats"
mkdir -p "$NAVI_CHEATS_DIR"

echo "Installing Navi cheatsheets..."
if [ -d "$SCRIPT_DIR/cheats" ]; then
    for cheat in "$SCRIPT_DIR"/cheats/*.cheat; do
        if [ -f "$cheat" ]; then
            cp "$cheat" "$NAVI_CHEATS_DIR/"
            echo "  ✓ Installed $(basename "$cheat")"
        fi
    done
fi
echo "✓ Navi cheatsheets installed."

# 4. Setup Navi Config (2-column view)
NAVI_CONFIG_DIR="$HOME/.config/navi"
mkdir -p "$NAVI_CONFIG_DIR"
if [ -f "$NAVI_CONFIG_DIR/config.yaml" ]; then
    echo "Backing up existing Navi config to $NAVI_CONFIG_DIR/config.yaml.bak_$TIMESTAMP..."
    cp "$NAVI_CONFIG_DIR/config.yaml" "$NAVI_CONFIG_DIR/config.yaml.bak_$TIMESTAMP"
fi
if [ -f "$SCRIPT_DIR/navi.yaml" ]; then
    cp "$SCRIPT_DIR/navi.yaml" "$NAVI_CONFIG_DIR/config.yaml"
    echo "✓ Navi config installed (2-column layout)."
fi

# 4. Setup Bash Config (~/.bashrc)
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ]; then
    echo "Backing up existing ~/.bashrc to $HOME/.bashrc.bak_$TIMESTAMP..."
    cp "$BASHRC" "$HOME/.bashrc.bak_$TIMESTAMP"
fi

cat << 'EOF' > "$BASHRC"
# ~/.bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Shell Prompt & PATH
PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"

# ------------------------------------------------------------------------------
# 1. Interactive Tool Hooks
# ------------------------------------------------------------------------------
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"
[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash
command -v navi &>/dev/null && eval "$(navi widget bash)"

# ------------------------------------------------------------------------------
# 2. Modern CLI Replacements
# ------------------------------------------------------------------------------
if command -v eza &>/dev/null; then
    alias ls="eza --icons --group-directories-first"
    alias ll="eza -l --icons --group-directories-first"
    alias la="eza -la --icons --group-directories-first"
fi

command -v bat &>/dev/null && alias cat="bat"

# ------------------------------------------------------------------------------
# 3. Essential Shortcuts
# ------------------------------------------------------------------------------
alias ..="cd .."
alias ...="cd ../.."

# Daily system maintenance (Shelly)
if command -v shelly &>/dev/null; then
    alias update="shelly upgrade all"
    alias cleanup="shelly purify standard -o"
fi

# Yazi directory sync (with signal trap for Ctrl+C cleanup)
function y() {
    local tmp="$(mktemp "${TMPDIR:-/tmp}/yazi-cwd.XXXXXX")"
    trap 'rm -f -- "$tmp"' RETURN INT TERM EXIT
    command yazi "$@" --cwd-file="$tmp"
    if [ -f "$tmp" ]; then
        local cwd="$(cat -- "$tmp")"
        [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
    fi
}
EOF
echo "✓ ~/.bashrc updated with essential daily shortcuts."

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Reload your shell:  source ~/.config/fish/config.fish"
echo "  2. Test Navi widget:   Press Ctrl+G in your terminal"
echo "  3. Test FZF file find: Press Ctrl+T in your terminal"
echo "  4. System update:      Run 'update' (shelly upgrade all)"
echo ""
