# AGENTS.md

## Overview
Modular collection of standalone desktop utilities, configuration scripts, and system fixes for Arch/Omarchy/Wayland.

## Structure
- `adguard-home/`: AdGuard Home setup scripts.
- `agy-switch/`: Rust account manager for Antigravity CLI (`agy-switch <id>`), with SQLite metadata, verified Secret Service writes, durable recovery, and preserved profile backups.
- `aikular/`: Custom markdown note helper (Python parser/render scripts).
- `cloudflare-warp/`: Cloudflare WARP (`wgcf`) setup guide.
- `copyparty/`: Setup for file-sharing web server (`copyparty`).
- `dolphin-tag/`: Tagging support scripts for Dolphin file manager.
- `git-autosquash/`: Git auto-squashing scripts.
- `git-autosync/`: Automated git sync utilities.
- `groq-ai/`: Unified Groq CLI assistant & global Wayland voice typing (`ai -v`).
- `kde-shortcuts/`: KDE Plasma keyboard shortcuts cheatsheet.
- `mpv/`: MPV media player configurations (`material-osc`, `thumbfast`).
- `ms-fonts/`: Microsoft TrueType fonts installation helpers.
- `rio/`: Setup/config files for Rio hardware-accelerated GPU terminal (Material 3 `dankcolors`, Vulkan backend, tabs/splits), Fish shell, Shelly package manager, and Navi cheatsheets.
- `strata/`: Strata file manager PKGBUILD and packaging setup for clean pacman updates.
- `tauri-webkit-lag/`: Fix for laggy Tauri/WebKitGTK apps (DMA-BUF renderer + KWin latency).

## Conventions
- Every module resides in its own subdirectory with an `apply_*.sh` installer and optional `revert_*.sh` uninstaller.
- Single-binary CLI tools install to `~/.local/bin/`.
- Dotfiles: Live user configurations and dotfiles are managed via `chezmoi` backed by the private GitHub repository `quantavil/dotfiles` (`~/.local/share/chezmoi`).
- `agy-switch`: Build/install with `./apply_agy-switch.sh`; it installs the Rust release binary. The module's `agy-switch` file is a development launcher; `legacy/agy-switch.py` is reference only. Do not install either as the production command.
- Minimal implementations; no bloated abstractions.

## Discoveries & Insights
- Streaming curl & jq: Use `sed -nu '/^data: \[DONE\]/d; s/^data: //p'` before `jq -j --unbuffered` to cleanly handle SSE lines and error JSON.
- `jq` boolean negation: Must use `(.prop | not)` because `not .prop` is parsed as `(not) .prop`.
- Non-streaming LLM responses: Strip `<think>` tags via `gsub("<(think|reasoning)>[\\s\\S]*?</(think|reasoning)>"; "")` before persisting.
- Global Wayland voice typing: `wtype` injects transcribed text directly into focused Wayland inputs without clipboard paste.
- Concurrent lock ownership: Use `HOLDS_LOCK` flag to prevent EXIT traps from deleting locks owned by other instances.
- Antigravity CLI auth: Stored in Secret Service keyring under service `'gemini'`, username `'antigravity'`; `zalando/go-keyring` reads default/login collection only.
- `agy-switch` v2: Saved credentials remain in private profile files, with separate persistent keyring copies. SQLite stores metadata only; `pending.json` holds recovery credentials. All credential backups are sensitive plaintext protected by permissions. Close running `agy` sessions before switch/login/recover; use `doctor` for diagnostics and `migrate` to verify keyring copies.
- GNOME Keyring 50 GKeyFile corruption: The unencrypted writer uses `g_key_file_set_value` but the reader uses `g_key_file_get_string`. Any application's multiline/backslash secret can corrupt the shared keyring; compact OAuth JSON and daemon restarts are insufficient. `agy-switch/apply_keyring-fix.sh` builds a one-line `g_key_file_set_string` patch and installs user systemd/D-Bus activation overrides. `--repair-unescaped-default` is ONLY for raw textual files written by the stock 50.0 daemon; it backs up and converts secrets offline to the existing binary-secret format. Never apply raw conversion to already escaped keyrings. See module README for update/rollback instructions.
- Keyring regression tests must use an empty C-string password (`printf '\0'`), not `printf '\n'` (which creates an encrypted keyring and misses the bug). Disable host service activation on the private test bus and verify the candidate daemon executable.
- SIGPIPE under pipefail: In bash with `set -o pipefail`, pipelines like `producer | grep -q` cause the producer to terminate with 141 (SIGPIPE) when `grep -q` closes the pipe early on match. Use `grep ... >/dev/null` instead of `grep -q` to consume normally without breaking `pipefail`.
- Rio modifier keyword: requires `control` (not `ctrl`); `with = "ctrl | shift"` silently drops control.
- Rio ANSI bright colors use prefix `light-*` (not `bright-*`).
- Niri Wayland alpha blending: requires `draw-border-with-background false` in window rules, or Niri renders an opaque backing rectangle.
- Margin syntax uses `margin = [12]`, and all root parameters must precede table headers in TOML.

## Blunders
- `agy-switch` profile metadata desync & overwrite: Never attribute refreshed credentials using the selected-profile marker alone. The Rust manager matches saved token identity before updating a profile.
- `agy-switch` session collection desync: Session storage is volatile and ignored by agy's default-collection lookup. The Rust manager targets the exact persistent default collection, rejects ambiguous active entries, and replaces without clearing first. Never restore the old clear-before-write behavior.
- `agy-switch` interrupted login: Persist captured credentials before the CLI exits, and report activation separately. Keep pending recovery records until activation or restoration succeeds; never print success after a failed write.
- `jq: error: Cannot index boolean`: Outer `if` lacked `else .` returning false, `not .started` parsed as `(not) .started`. Fix: Wrapped as `(.started | not)`.
- EXIT trap deleted other lock dirs: Unconditional lock cleanup deleted directories created by concurrent runs. Fix: Added `HOLDS_LOCK` ownership flag.
- HTTP status check failed on 100 Continue: Reading first header line failed when 100 Continue preceded 200 OK. Fix: Parsed last status line via `awk`.
- Repetitive summary formatting loop: Persisted `<think>` block in history summary field. Fix: Added `gsub` sanitization to `load_history`.
- `material-osc` nested directories: Zip file already packaged root `scripts/` and `fonts/`. Fix: Extracted directly to `~/.config/mpv/`.
- `ms-fonts` missing Cambria & SIGPIPE verification failure: Font discovery only matched `*.ttf`, skipping Cambria (`cambria.ttc`) and other TrueType collections. In addition, `fc-list | grep -qi` failed under `set -euo pipefail` due to SIGPIPE (exit 141). Fix: Matched `*.ttf`, `*.ttc`, and `*.otf`, and redirected grep to `/dev/null`.
