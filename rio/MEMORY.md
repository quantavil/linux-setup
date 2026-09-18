# Project: rio

## Overview
Modular configuration and deployment setup for Rio GPU-accelerated terminal (Material 3 `dankcolors`, Vulkan backend), Fish shell, Shelly package manager, and Navi interactive cheatsheets.

## Structure
```text
linux-setup/rio/
├── apply_rio_setup.sh   # Module installer (creates timestamped backups)
├── revert_rio_setup.sh  # Module uninstaller (restores backups)
├── config.toml          # Rio terminal configuration (dankcolors, margin, Vulkan, cursor trail)
├── config.fish          # Minimal Fish shell configuration (Shelly, Navi, Yazi)
├── navi.yaml            # Navi finder configuration (2-column layout)
├── cheats/              # Custom Navi cheatsheets
│   └── personal.cheat   # Package management, git, and search shortcuts
├── README.md            # Deployment and usage guide
└── MEMORY.md            # Technical discoveries and compositor integration notes
```

## Conventions
- **Module Standard**: Adheres to `AGENTS.md` with `apply_rio_setup.sh` and `revert_rio_setup.sh`.
- **Root Key Precedence**: In TOML, root-level keys (`margin`, `scrollback-history-limit`, `confirm-before-quit`) must be defined at the top of `config.toml` before any section tables (`[window]`, `[colors]`), or TOML assigns them to preceding tables.
- **Native Multiplexing**: Rio natively provides hardware-accelerated tabs and splits without multiplexer overhead.

## Dependencies & Setup
- **Core**: `rio`, `fish`, `navi`, `shelly`, `fzf`, `yazi`, `bat`, `eza`, `zoxide`, `jq`
- **Optional**: `shelly-flatpak-backend` (Flatpak management)

## Insights & Discoveries
- **Modifier Keyword Syntax**: Rio's configuration parser strictly expects `control` (not `ctrl`). Writing `with = "ctrl | shift"` silently ignores the control modifier and registers `Shift` only. Always use `with = "control | shift"`.
- **Bright ANSI Color Keys**: Rio's color scheme parser uses the `light-*` prefix (e.g. `light-black`, `light-red`), not `bright-*`.
- **Niri Wayland Alpha Blending**: Rio's window opacity requires `draw-border-with-background false` in Niri window rules; otherwise Niri renders an opaque backing rectangle behind transparent clients.
- **Margin Syntax**: Window margins use `margin = [12]` (array format), which must precede any table headers in TOML.
- **Split & Pane Action Identifiers**:
  - Horizontal split (side-by-side): `SplitRight`
  - Vertical split (stacked): `SplitDown`
  - Split navigation: `SelectNextSplit`, `SelectPrevSplit`
  - Close pane/tab: `CloseSplitOrTab`
- **Vulkan Pipeline Caching**: Sugarloaf caches Vulkan pipeline bytecode in `~/.cache/rio/sugarloaf-vulkan.cache`, yielding sub-millisecond subsequent starts.
- **Shelly CLI Subcommands**: `shelly upgrade` and `shelly purify` require subcommands. Full upgrade is `shelly upgrade all` (`-U`); orphan and cache purge is `shelly purify standard -o` (`-Zso`).
- **Fish Completion Collision**: CachyOS vendor defaults define pacman wrappers on `update`. Custom aliases require clearing old completions with `complete -e -c update` and `complete -e -c cleanup`.
- **Yazi Directory Sync**: Use `mktemp -t` and `builtin cd -- "$cwd"` to prevent argument injection on directories starting with `-`. In Bash, register traps on `RETURN INT TERM EXIT` to guarantee temporary file cleanup.
- **Navi Dynamic Selectors**: Using `$ package_name: pacman -Qq` in `.cheat` files triggers interactive fuzzy pickers for arguments instead of plain prompts.
