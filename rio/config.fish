# Source vendor CachyOS Fish configuration if available
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# User binary path
fish_add_path -g "$HOME/.local/bin"

if status is-interactive
    # Directory jumping & interactive widgets
    type -q zoxide && zoxide init fish | source
    type -q navi && navi widget fish | source

    # Modern CLI aliases (eza, bat)
    if type -q eza
        alias ls="eza --icons --group-directories-first"
        alias ll="eza -lh --icons --group-directories-first"
        alias la="eza -lah --icons --group-directories-first"
        alias tree="eza --tree --icons --level=2"
    end

    if type -q bat
        alias cat="bat --paging=never"
    end
end

# Shelly package manager shortcuts
if type -q shelly
    # Clear vendor CachyOS completions to prevent flag collisions
    complete -e -c update
    complete -e -c cleanup

    alias update="shelly upgrade all"
    alias cleanup="shelly purify standard -o"
end

# Yazi wrapper with working directory sync on exit
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
