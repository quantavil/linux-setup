# ==============================================================================
# ENVIRONMENT AND PATH CONFIGURATION
# ==============================================================================
# Source vendor CachyOS Fish configuration if available
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# Canonical user binary path injection
fish_add_path -g "$HOME/.local/bin"

# ==============================================================================
# NATIVE INTERACTIVE SHELL INITIALIZATION
# ==============================================================================
if status is-interactive
    # Directory navigation jumping
    type -q zoxide && zoxide init fish | source

    # Navi interactive cheatsheet widget (Ctrl+G)
    type -q navi && navi widget fish | source
end

# ==============================================================================
# PACKAGE MANAGEMENT MAPPINGS (SHELLY)
# ==============================================================================
if type -q shelly
    # Clear vendor CachyOS pacman completions to prevent flag collisions
    complete -e -c update
    complete -e -c cleanup

    # Unified upgrades across standard repos, AUR, Flatpaks, and AppImages
    alias update="shelly upgrade all"
    # Clean orphaned packages and purge package cache
    alias cleanup="shelly purify standard -o"
end

# ==============================================================================
# HIGH-PERFORMANCE LOGICAL FUNCTIONS
# ==============================================================================
# Yazi Working Directory Sync Tool
# Safely synchronizes terminal working directory on Yazi exit
function y
    set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
    command yazi $argv --cwd-file="$tmp"
    if test -f "$tmp"
        set -l cwd (command cat -- "$tmp" | string collect)
        if test -n "$cwd"; and test "$cwd" != "$PWD"
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
    end
end
