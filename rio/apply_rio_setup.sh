#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

echo "=== Rio, Fish, Bash & Navi Setup Installer ==="
echo ""

# Check dependencies
echo "Checking installed tools..."
for cmd in rio fish navi fzf shelly eza bat zoxide yazi; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  ✓ $cmd"
    else
        echo "  ⚠ $cmd is not found in PATH"
    fi
done
echo ""

# 1. Setup Rio Config (~/.config/rio/config.toml)
RIO_DIR="$HOME/.config/rio"
mkdir -p "$RIO_DIR"

if [ -f "$RIO_DIR/config.toml" ]; then
    echo "Backing up existing Rio config to $RIO_DIR/config.toml.bak_$TIMESTAMP..."
    cp "$RIO_DIR/config.toml" "$RIO_DIR/config.toml.bak_$TIMESTAMP"
fi
echo "Installing Rio config..."
cp "$SCRIPT_DIR/config.toml" "$RIO_DIR/config.toml"
echo "✓ Rio config installed."

# 2. Setup Fish Config (~/.config/fish/config.fish)
FISH_DIR="$HOME/.config/fish"
mkdir -p "$FISH_DIR"

if [ -f "$FISH_DIR/config.fish" ]; then
    echo "Backing up existing Fish config to $FISH_DIR/config.fish.bak_$TIMESTAMP..."
    cp "$FISH_DIR/config.fish" "$FISH_DIR/config.fish.bak_$TIMESTAMP"
fi
echo "Installing Fish config..."
cp "$SCRIPT_DIR/config.fish" "$FISH_DIR/config.fish"
echo "✓ Fish config installed."

# 3. Setup Navi Cheatsheets (~/.local/share/navi/cheats/)
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

# 4. Setup Navi Config (~/.config/navi/config.yaml)
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

# 5. Setup Bash Config (~/.bashrc)
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ]; then
    echo "Backing up existing ~/.bashrc to $HOME/.bashrc.bak_$TIMESTAMP..."
    cp "$BASHRC" "$HOME/.bashrc.bak_$TIMESTAMP"
fi

cat << 'EOF' > "$BASHRC"
# ~/.bashrc

[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"

# Interactive tool hooks
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash
command -v navi >/dev/null 2>&1 && eval "$(navi widget bash)"

# Modern CLI replacements
if command -v eza >/dev/null 2>&1; then
    alias ls="eza --icons --group-directories-first"
    alias ll="eza -l --icons --group-directories-first"
    alias la="eza -la --icons --group-directories-first"
fi

command -v bat >/dev/null 2>&1 && alias cat="bat"

alias ..="cd .."
alias ...="cd ../.."

# Daily system maintenance (Shelly)
if command -v shelly >/dev/null 2>&1; then
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
