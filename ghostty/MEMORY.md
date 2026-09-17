# Project: ghostty

## Overview
A minimalist configuration and deployment repository for setting up a high-performance terminal and shell environment using Ghostty (with `dankcolors` Material 3 styling), Fish shell, Shelly package manager, and Navi interactive cheatsheets.

## Structure
```
linux-setup/ghostty/
├── apply_ghostty_setup.sh   # Module installer (creates timestamped backups)
├── revert_ghostty_setup.sh  # Module uninstaller (restores backups)
├── config                   # Ghostty terminal configuration (dankcolors, blur, padding)
├── config.fish              # Minimal Fish shell configuration (Shelly, Navi, Yazi)
├── cheats/                  # Custom Navi cheatsheets
│   └── personal.cheat       # System inspection, Shelly, and Apktool commands
├── README.md                # Deployment and usage guide
└── MEMORY.md                # Project memory and history
```

## Conventions
- **Module Standard**: Adheres to `AGENTS.md` with `apply_ghostty_setup.sh` and `revert_ghostty_setup.sh`.
- **Minimalist Shell**: Inspection and one-off administrative commands belong in Navi cheatsheets, NOT cluttered in shell rc files.
- **Native Terminals**: Avoid multiplexer layers like tmux when Ghostty natively provides Wayland tabs and splits with Material 3 styling.

## Dependencies & Setup
- **Core**: `ghostty`, `fish`, `navi`, `shelly`, `fzf`, `yazi`, `bat`, `eza`, `zoxide`, `jq`
- **Optional**: `shelly-flatpak-backend` (Flatpak integration)

## Insights & Discoveries
- **Shelly CLI Arguments**: `shelly upgrade` and `shelly purify` require subcommands. The true full-system upgrade is `shelly upgrade all` (or `-U`), and orphan removal + cache scrubbing is `shelly purify standard -o` (or `-Zso`). Bare commands only print help.
- **Ghostty Keybinding Collision**: Binding `ctrl+t=new_tab` in Ghostty hijacks `Ctrl+T`, breaking FZF's core file finder and readline character transpose. Native `Ctrl+Shift+T` is preferred for tabs.
- **Fish Completion Collision**: CachyOS defaults bind pacman completion wrappers to `update`. Overriding `update` requires running `complete -e -c update` and `complete -e -c cleanup` first to avoid stacked ghost pacman flags.
- **Yazi Path Safety**: In Fish, use `mktemp -t` and `builtin cd -- "$cwd"` to prevent directory names starting with `-` from triggering option flags. In Bash, trap `RETURN INT TERM EXIT` to prevent leaking temp files in `/tmp` upon `Ctrl+C`.
- **Navi Dynamic Selectors**: Using `$ package_name: pacman -Qq` and `$ apk_file: find . -name "*.apk"` in `.cheat` files creates interactive fuzzy pickers for arguments instead of empty text prompts.
