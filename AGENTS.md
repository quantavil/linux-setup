# AGENTS.md

## Overview
Modular collection of standalone desktop utilities, configuration scripts, and system fixes for Arch/Omarchy/Wayland.

## Structure
- `adguard-home/`: AdGuard Home setup scripts.
- `agy-switch/`: Fast profile & account switcher for Antigravity CLI dual Pro accounts (`agy-switch`).
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
- Antigravity CLI auth: Stored in Secret Service keyring under service `'gemini'` (fallback `~/.gemini/antigravity-cli/antigravity-oauth-token`); atomic swap enables sub-10ms account switching.

## Blunders
- `jq: error: Cannot index boolean`: Outer `if` lacked `else .` returning false, `not .started` parsed as `(not) .started`. Fix: Wrapped as `(.started | not)`.
- EXIT trap deleted other lock dirs: Unconditional lock cleanup deleted directories created by concurrent runs. Fix: Added `HOLDS_LOCK` ownership flag.
- HTTP status check failed on 100 Continue: Reading first header line failed when 100 Continue preceded 200 OK. Fix: Parsed last status line via `awk`.
- Repetitive summary formatting loop: Persisted `<think>` block in history summary field. Fix: Added `gsub` sanitization to `load_history`.
- `material-osc` nested directories: Zip file already packaged root `scripts/` and `fonts/`. Fix: Extracted directly to `~/.config/mpv/`.
