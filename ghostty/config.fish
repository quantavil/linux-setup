# ==============================================================================
# ENVIRONMENT AND PATH CONFIGURATION
# ==============================================================================
# Ensure ~/.local/bin is in PATH for custom user scripts
if not contains "$HOME/.local/bin" $PATH
    set -gx PATH "$HOME/.local/bin" $PATH
end

# Groq API Key for the 'ai' command line assistant (obtain from console.groq.com)
# set -gx GROQ_API_KEY "your_groq_api_key_here"

# ==============================================================================
# NATIVE INTERACTIVE SHELL INITIALIZATION
# ==============================================================================
if status is-interactive
    # Initialize frecency-based directory tracker
    zoxide init fish | source
end

# ==============================================================================
# SECURITY SANDBOXING DEFINITIONS
# ==============================================================================
# Force network tools through containment layers if firejail is installed
if type -q firejail
    alias curl="firejail curl"
    alias wget="firejail wget"
end
alias pip="python3 -m pip"

# ==============================================================================
# CORE NAVIGATION AND FILE MANIPULATION ALIASES
# ==============================================================================
# Map standard paths to eza features with strict group structuring
alias ls="eza --icons --group-directories-first"
alias ll="eza --icons --group-directories-first -l"
alias la="eza --icons --group-directories-first -la"
alias tree="eza --icons --tree"

# General short-hand utilities
alias cat="bat"
alias c="clear"
alias sizeof="du -sh"

# ==============================================================================
# PACKAGE MANAGEMENT MAPPINGS
# ==============================================================================
# Arch Linux Package Manager (Paru/Pacman)
alias update="sudo pacman -Syu"
alias install="sudo pacman -S"
alias aur="paru -S"
alias remove="sudo pacman -Rns"
alias search="paru -Ss"
alias cleanup="sudo paccache -rk2 && paru -Sc --noconfirm"
alias tg="topgrade"

# ==============================================================================
# SYSTEM INSPECTION AND METRIC WRAPPERS
# ==============================================================================
alias top="btop"
alias ff="fastfetch"
alias ports="ss -tuln"
alias myip="curl -s ifconfig.me"
alias port-whisperer="bunx port-whisperer --all"

# Log viewer configuration
alias logs="journalctl -b -p err"

# ==============================================================================
# TMUX ALIASES
# ==============================================================================
alias tk="tmux kill-session -t"
alias ta="tmux attach -t"
alias tl="tmux list-sessions"

# ==============================================================================
# TMUX PROGRAMMATIC WORKSPACE ENGINES (SMART RESUME CODES)
# ==============================================================================

# LAYOUT 1: 2 Columns split evenly down the middle
function wd2c
    if tmux has-session -t ws1 2>/dev/null
        tmux attach-session -t ws1
    else
        tmux new-session -d -s ws1 ';' \
            split-window -h -t ws1 ';' \
            attach-session -t ws1
    end
end

# LAYOUT 2: 3 Panes Grid (Left side is a large panel, right side is stacked)
function wd3g
    if tmux has-session -t ws2 2>/dev/null
        tmux attach-session -t ws2
    else
        tmux new-session -d -s ws2 "agy --dangerously-skip-permissions; exec fish" ';' \
            split-window -h -t ws2 "timr; exec fish" ';' \
            split-window -v -t ws2 "lowfi; exec fish" ';' \
            attach-session -t ws2
    end
end

# LAYOUT 3: 4 Panes Grid (Balanced 2x2 grid layout)
function wd4g
    if tmux has-session -t ws3 2>/dev/null
        tmux attach-session -t ws3
    else
        tmux new-session -d -s ws3 ';' \
            split-window -h -t ws3 ';' \
            split-window -h -t ws3 ';' \
            split-window -h -t ws3 ';' \
            select-layout -t ws3 tiled ';' \
            attach-session -t ws3
    end
end

# ==============================================================================
# HIGH-PERFORMANCE LOGICAL FUNCTIONS (NATIVE FISH PIPELINES)
# ==============================================================================

# Yazi Working Directory Sync Tool
# Saves target exit paths to state variables to sync terminal path on quit
function y
    set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if test -f "$tmp"
        set -l cwd (command cat "$tmp")
        if test -n "$cwd"; and test "$cwd" != "$PWD"
            builtin cd "$cwd"
        end
    end
    rm -f "$tmp"
end

# Orphaned Repository Packages Scrubber
# Arrays are verified natively via state checkers before firing actions
function orphans
    set -l list (pacman -Qdtq)
    if test -n "$list"
        sudo pacman -Rns $list
    else
        echo "No orphans found"
    end
end

# Interactive Fuzzy FZF Application Removal Wrapper
# Prevents execution errors if lookups are cancelled early via escape keys
function fuzzy-remove
    set -l targets (paru -Qq | fzf --multi --preview "paru -Qi {1}")
    if test -n "$targets"
        paru -Rns $targets
    end
end

# Core Storage Allocation Profile Query
# Isolates local database metadata fields to track top 30 space allocations
function pacsize
    pacman -Qi | awk '/^Name/{n=$3}/^Installed Size/{print $4,$5,n}' | sort -rh | head -30
end

# Interactive Storage Profiler via Fuzzy Target Overlays
function pacsize-fzf
    pacman -Qi | awk '/^Name/{n=$3}/^Installed Size/{print $4,$5,n}' | sort -rh | fzf
end
