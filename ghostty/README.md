# Ghostty + Fish + Navi Terminal Environment

Modern, minimalist terminal and shell environment featuring Ghostty (`dankcolors` Material 3 styling), Fish shell, Shelly package manager, and Navi interactive cheatsheets.

---

## What It Does

- **Ghostty Terminal Configuration:** Borderless Wayland window with 32px blur radius, 12px padding, Material 3 split fill (`#44464f`), and native tab/zoom shortcuts.
- **Minimalist Fish Shell:** Stripped-down, high-performance `config.fish` (~35 lines) that builds cleanly on CachyOS vendor defaults without alias clutter or missing binary calls.
- **Shelly Integration:** Replaces Topgrade with Shelly ALPM (`shelly upgrade all` for standard repos, AUR, Flatpaks, and AppImages; `shelly purify standard -o` for cache and orphan scrubbing).
- **Interactive Navi Cheatsheets:** Binds `Ctrl + G` directly in the shell to search, filter, and auto-complete everyday inspection, maintenance, and Apktool commands without cluttering shell configurations.
- **Bash Parity:** Updates `~/.bashrc` with matching daily shortcuts (`eza`, `bat`, `yazi`, `update`, `cleanup`, and `fzf`/`navi` widgets) if you ever drop into Bash.
- **Directory-Sync Yazi Wrapper (`y`):** Seamless file manager wrapper with signal trapping that syncs your terminal working directory on exit.

---

## Prerequisites

Install core tools on CachyOS / Arch Linux:

```bash
sudo pacman -S ghostty fish yazi micro fzf bat eza zoxide fastfetch wl-clipboard jq navi shelly
```
*(Flatpak management is provided by `shelly-flatpak-backend`)*

---

## Usage

### Apply Setup

Run the setup installer from the module directory:

```bash
./apply_ghostty_setup.sh
```

Or from the repository root:

```bash
bash ghostty/apply_ghostty_setup.sh
```

The installer automatically:
1. Verifies that all required CLI tools are present.
2. Creates timestamped backups of `~/.config/ghostty/config`, `~/.config/fish/config.fish`, and `~/.bashrc`.
3. Deploys the Ghostty configuration, Fish shell configuration, Bash parity, and Navi cheatsheet.

### Revert Setup

To restore your configurations from the latest backups:

```bash
./revert_ghostty_setup.sh
```

Or skip confirmation with `-y`:

```bash
./revert_ghostty_setup.sh -y
```

---

## Layout Structure

```text
linux-setup/ghostty/
├── apply_ghostty_setup.sh   # Automated setup script with timestamped backups
├── revert_ghostty_setup.sh  # Rollback script to restore previous configs
├── config                   # Ghostty terminal config -> ~/.config/ghostty/config
├── config.fish              # Fish shell config       -> ~/.config/fish/config.fish
├── cheats/                  # Custom Navi cheatsheets -> ~/.local/share/navi/cheats/
│   └── personal.cheat       # System inspection, Shelly, and Apktool shortcuts
├── README.md                # Deployment and usage documentation
└── MEMORY.md                # Technical insights and edge case documentation
```

---

## Keybindings & Shortcuts Reference

### Terminal & Shell Shortcuts

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| **`Ctrl + G`** | Open interactive Navi cheatsheet popup | Fish & Bash |
| **`Ctrl + T`** | Fuzzy-find files with FZF | Fish & Bash |
| **`Ctrl + R`** | Fuzzy-find command history with FZF | Bash (`Ctrl+R` in Fish) |
| **`Ctrl + Shift + N`** | Open new Ghostty window | Ghostty |
| **`Ctrl + Shift + T`** | Open new Ghostty tab | Ghostty |
| **`Ctrl + +` / `Ctrl + -`** | Zoom in / Zoom out font size | Ghostty |
| **`Ctrl + 0`** | Reset font size to default (12pt) | Ghostty |
| **`Shift + Enter`** | Insert literal newline without executing | Ghostty |

### Shell Commands

| Command | Action | Description |
| :--- | :--- | :--- |
| **`update`** | `shelly upgrade all` | Unified upgrade: Arch repos + AUR + Flatpaks + AppImages |
| **`cleanup`** | `shelly purify standard -o` | Purges orphaned packages and trims package cache |
| **`y`** | `yazi` (with cwd sync) | Visual terminal file manager (syncs `$PWD` on exit) |
| **`z <dir>`** | `zoxide` directory jump | Instant frecency-based directory jumping |
| **`ls` / `ll` / `la`** | `eza` | Modern directory listing with icons and grouped directories |
| **`cat`** | `bat` | File display with syntax highlighting |

---

## Navi Cheatsheet (`personal.cheat`)

Press **`Ctrl + G`** anywhere on your prompt to search and execute:

* **User Installed Packages:**
  * Fuzzy search all user-installed packages with live info (`pacman -Qe | fzf`)
  * Filter explicitly installed AUR packages only (`pacman -Qem`)
  * Filter explicitly installed Official repo packages only (`pacman -Qen`)
  * Filter top-level standalone packages (`pacman -Qet`)
  * Interactive package removal with `Tab` multi-select and preview (`shelly remove`)
  * Interactive package search and install from repos (`shelly install`)
  * Remove pacman database lock (`sudo rm -f /var/lib/pacman/db.lck`)
  * Review and merge `.pacnew` system configurations (`sudo pacdiff -s`)
  * TOML package backup (`shelly backup`) and cached package downgrades (`shelly downgrade`)
* **Git Workflows (with FZF):**
  * Interactive switch git branch with live recent commit previews
  * Interactive browse commit history with live syntax-highlighted diff preview
  * Interactive stage modified files with `Tab` multi-select (`git add`)
  * Interactive discard uncommitted changes in files (`git restore`)
* **File & Text Search (with FZF):**
  * Fuzzy find files with syntax-highlighted preview and open in editor
  * Live ripgrep text search across project with line preview and editor jump
* **System & Network:**
  * Interactive open ports and listening apps inspector (`sudo ss -tulpn | fzf`)
  * Restart PipeWire audio engine (`systemctl --user restart pipewire wireplumber`)
  * Check public external IP (`curl -s ifconfig.me`)