# Rio + Fish + Navi Terminal Environment

Hardware-accelerated, minimalist terminal and shell environment featuring Rio (`dankcolors` Material 3 styling on Vulkan), Fish shell, Shelly package manager, and Navi interactive cheatsheets.

## Overview

- **Rio Terminal Configuration:** Borderless Wayland window with 12px padding, warm dark Material 3 `dankcolors` palette, animated cursor trail (`#ffb3ae`), native tabs and splits with active/unfocused split styling (`#44464f`).
- **GPU Hardware Acceleration:** Native Vulkan backend rendering powered by Rio's Sugarloaf graphics engine.
- **Dedicated Split & Tab Keybindings:** Built-in shortcut mapping for horizontal splits (`Ctrl + Shift + D`), vertical splits (`Ctrl + Shift + E`), split navigation (`Ctrl + Shift + ]` / `[`), tabs (`Ctrl + Shift + T`), and font zoom.
- **Minimalist Fish Shell:** Fast, high-performance `config.fish` building cleanly on CachyOS vendor defaults without alias clutter or missing binary calls.
- **Shelly Integration:** Unified upgrades via Shelly ALPM (`shelly upgrade all` for standard repos, AUR, Flatpaks, and AppImages; `shelly purify standard -o` for cache and orphan scrubbing).
- **Interactive Navi Cheatsheets:** Binds `Ctrl + G` directly in the shell to search, filter, and execute package management, git, search, and system commands.
- **Bash Parity:** Updates `~/.bashrc` with matching daily shortcuts (`eza`, `bat`, `yazi`, `update`, `cleanup`, and `fzf`/`navi` widgets).
- **Directory-Sync Yazi Wrapper (`y`):** Terminal file manager wrapper that syncs working directory on exit.

## Prerequisites

Install core tools on CachyOS / Arch Linux:

```bash
sudo pacman -S rio fish yazi micro fzf bat eza zoxide fastfetch wl-clipboard jq navi shelly
```
*(Flatpak management is provided by `shelly-flatpak-backend`)*

## Usage

### Apply Setup

Run the setup installer:

```bash
./apply_rio_setup.sh
```

Or from the repository root:

```bash
bash rio/apply_rio_setup.sh
```

The installer:
1. Verifies that required CLI tools are present.
2. Creates timestamped backups of `~/.config/rio/config.toml`, `~/.config/fish/config.fish`, `~/.config/navi/config.yaml`, and `~/.bashrc`.
3. Deploys the Rio configuration, Fish shell configuration, Bash parity, and Navi cheatsheet.

### Revert Setup

Restore configurations from the latest backups:

```bash
./revert_rio_setup.sh
```

Or skip confirmation:

```bash
./revert_rio_setup.sh -y
```

## Structure

```text
linux-setup/rio/
├── apply_rio_setup.sh   # Automated setup script with timestamped backups
├── revert_rio_setup.sh  # Rollback script to restore previous configs
├── config.toml          # Rio terminal config    -> ~/.config/rio/config.toml
├── config.fish          # Fish shell config      -> ~/.config/fish/config.fish
├── navi.yaml            # Navi 2-column config   -> ~/.config/navi/config.yaml
├── cheats/              # Custom Navi cheatsheets -> ~/.local/share/navi/cheats/
│   └── personal.cheat   # Package management, git, and search shortcuts
├── README.md            # Deployment and usage documentation
└── MEMORY.md            # Technical insights and edge case documentation
```

## Keybindings & Shortcuts Reference

### Terminal & Navigation Shortcuts (Rio)

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| **`Ctrl + Shift + N`** | `CreateWindow` | Open new Rio window |
| **`Ctrl + Shift + T`** | `CreateTab` | Open new Rio tab |
| **`Ctrl + Shift + W`** | `CloseSplitOrTab` | Close current split pane or tab |
| **`Ctrl + Shift + D`** | `SplitRight` | Split terminal pane horizontally (right) |
| **`Ctrl + Shift + E`** | `SplitDown` | Split terminal pane vertically (down) |
| **`Ctrl + Shift + ]`** | `SelectNextSplit` | Cycle focus to next split pane |
| **`Ctrl + Shift + [`** | `SelectPrevSplit` | Cycle focus to previous split pane |
| **`Ctrl + +` / `Ctrl + =`** | `IncreaseFontSize` | Zoom in font size |
| **`Ctrl + -`** | `DecreaseFontSize` | Zoom out font size |
| **`Ctrl + 0`** | `ResetFontSize` | Reset font size to default (16.0) |
| **`Ctrl + Shift + C`** | `Copy` | Copy selection to system clipboard |
| **`Ctrl + Shift + V`** | `Paste` | Paste from system clipboard |
| **`Ctrl + Shift + F`** | `SearchForward` | Open search / find in buffer |

### Shell Shortcuts

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| **`Ctrl + G`** | Open interactive Navi cheatsheet popup | Fish & Bash |
| **`Ctrl + T`** | Fuzzy-find files with FZF | Fish & Bash |
| **`Ctrl + R`** | Fuzzy-find command history with FZF | Fish & Bash |

### Daily Commands

| Command | Action | Description |
| :--- | :--- | :--- |
| **`update`** | `shelly upgrade all` | Unified upgrade: Arch repos + AUR + Flatpaks + AppImages |
| **`cleanup`** | `shelly purify standard -o` | Purges orphaned packages and trims package cache |
| **`y`** | `yazi` (with cwd sync) | Visual terminal file manager (syncs `$PWD` on exit) |
| **`z <dir>`** | `zoxide` directory jump | Frecency-based directory jumping |
| **`ls` / `ll` / `la`** | `eza` | Modern directory listing with icons and grouped directories |
| **`cat`** | `bat` | File display with syntax highlighting |

## Navi Cheatsheet (`personal.cheat`)

Press **`Ctrl + G`** anywhere on your prompt to search and execute:

- **Package Management:**
  - Fuzzy search user-installed packages with live info (`pacman -Qe | fzf`)
  - Filter explicitly installed AUR packages (`pacman -Qem`) or Official repo packages (`pacman -Qen`)
  - Filter top-level standalone packages (`pacman -Qet`)
  - Interactive package removal with `Tab` multi-select and preview (`shelly remove`)
  - Interactive package search and install from repos (`shelly install`)
  - Remove pacman database lock (`sudo rm -f /var/lib/pacman/db.lck`)
  - Review and merge `.pacnew` system configurations (`sudo pacdiff -s`)
  - TOML package backup (`shelly backup`) and cached package downgrades (`shelly downgrade`)
- **Git Workflows (with FZF):**
  - Interactive git branch switch with live recent commit previews
  - Interactive browse commit history with syntax-highlighted diff preview
  - Interactive stage modified files with `Tab` multi-select (`git add`)
  - Interactive discard uncommitted changes in files (`git restore`)
- **File & Text Search (with FZF):**
  - Fuzzy find files with syntax-highlighted preview and open in editor
  - Live ripgrep text search across project with line preview and editor jump
- **System & Network:**
  - Interactive open ports and listening apps inspector (`sudo ss -tulpn | fzf`)
  - Restart PipeWire audio subsystem (`systemctl --user restart pipewire pipewire-pulse wireplumber`)
  - Check public external IP (`curl -s ifconfig.me`)
