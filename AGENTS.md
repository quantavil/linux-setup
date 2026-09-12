# AGENTS.md

## Overview
Modular collection of standalone desktop utilities, configuration scripts, and system fixes for Arch/Omarchy/Wayland.

## Structure
- `adguard-home/`: AdGuard Home setup scripts.
- `agy-switch/`: Fast profile & account switcher for Antigravity CLI triple Pro accounts (`agy-switch <1|2|3>`).
- `aikular/`: Custom markdown note helper (Python parser/render scripts).
- `cloudflare-warp/`: Cloudflare WARP (`wgcf`) setup guide.
- `copyparty/`: Setup for file-sharing web server (`copyparty`).
- `dolphin-tag/`: Tagging support scripts for Dolphin file manager.
- `ghostty/`: Setup/config files for Ghostty terminal & Fish shell.
- `git-autosquash/`: Git auto-squashing scripts.
- `git-autosync/`: Automated git sync utilities.
- `groq-ai/`: Unified Groq CLI assistant & global Wayland voice typing (`ai -v`).
- `kde-shortcuts/`: KDE Plasma keyboard shortcuts cheatsheet.
- `mpv/`: MPV media player configurations (`material-osc`, `thumbfast`).
- `ms-fonts/`: Microsoft TrueType fonts installation helpers.
- `strata/`: Strata file manager PKGBUILD and packaging setup for clean pacman updates.
- `tauri-webkit-lag/`: Fix for laggy Tauri/WebKitGTK apps (DMA-BUF renderer + KWin latency).

## Conventions
- Every module resides in its own subdirectory with an `apply_*.sh` installer and optional `revert_*.sh` uninstaller.
- Single-binary CLI tools install to `~/.local/bin/`.
- Minimal implementations; no bloated abstractions.

## Discoveries & Insights
- Streaming curl & jq: Use `sed -nu '/^data: \[DONE\]/d; s/^data: //p'` before `jq -j --unbuffered` to cleanly handle SSE lines and error JSON.
- `jq` boolean negation: Must use `(.prop | not)` because `not .prop` is parsed as `(not) .prop`.
- Non-streaming LLM responses: Strip `<think>` tags via `gsub("<(think|reasoning)>[\\s\\S]*?</(think|reasoning)>"; "")` before persisting.
- Global Wayland voice typing: `wtype` injects transcribed text directly into focused Wayland inputs without clipboard paste.
- Concurrent lock ownership: Use `HOLDS_LOCK` flag to prevent EXIT traps from deleting locks owned by other instances.
- Antigravity CLI auth: Stored in Secret Service keyring under service `'gemini'`, username `'antigravity'`; `zalando/go-keyring` reads default/login collection only.
- GNOME Keyring 50 GKeyFile corruption: Unescaped newlines in any secret fail `g_key_file_load_from_data`, dropping the collection from D-Bus and hanging `secret-tool store`. Fix: Escape newlines as `\n` and unlock default collection via D-Bus before store.

## Blunders
- `agy-switch` profile metadata desync & overwrite: Reading stale `profile.json` before `token.json` masked account identity; `save_active_to_profile` clobbered profiles with foreign active tokens. Fix: Make `token.json` JWT payload authoritative for email and guard `save_active_to_profile` against mismatched emails.
- `agy-switch` session collection desync: Storing with `--collection=session` bypassed default keyring; `agy` (`go-keyring`) only queries `default`, staying stuck on old account while `secret-tool lookup` falsely matched `session`. Fix: Target default keyring with `secret-tool store` and clear stale session items.
- `jq: error: Cannot index boolean`: Outer `if` lacked `else .` returning false, `not .started` parsed as `(not) .started`. Fix: Wrapped as `(.started | not)`.
- EXIT trap deleted other lock dirs: Unconditional lock cleanup deleted directories created by concurrent runs. Fix: Added `HOLDS_LOCK` ownership flag.
- HTTP status check failed on 100 Continue: Reading first header line failed when 100 Continue preceded 200 OK. Fix: Parsed last status line via `awk`.
- Repetitive summary formatting loop: Persisted `<think>` block in history summary field. Fix: Added `gsub` sanitization to `load_history`.
- `material-osc` nested directories: Zip file already packaged root `scripts/` and `fonts/`. Fix: Extracted directly to `~/.config/mpv/`.
