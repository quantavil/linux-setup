# Groq AI — CLI Assistant & Global Voice Typing

A unified, lightweight Linux tool combining a high-speed streaming AI assistant with system-wide voice typing for Wayland (**Hyprland / Omarchy**).

---

## Features

- **⚡ Blazing Fast**: Powered by Groq's low-latency LPU inference.
- **🎙 Global Voice Typing**: Press a keyboard shortcut anywhere (e.g., in your browser, search bar, text editor), speak, and press again — the transcript is automatically typed into your active window via `wtype` and copied to the clipboard (`wl-copy`).
- **💬 Conversational Memory**: Preserves context between terminal prompts with automatic rolling summarization (~20k tokens) to save tokens.
- **✨ Zero-Flag Interactive REPL**: Running `ai` without arguments enters interactive chat mode.
- **🗣️ Direct Voice-to-LLM (`ai -V`)**: Dictate a question with your voice and receive a streamed AI answer directly.
- **🔍 Web Search**: Built-in web search via Groq compound models (`ai -s`).
- **📦 Zero Heavy Dependencies**: Pure Bash, `curl`, `jq`, and native Linux desktop tools. No Python pip packages, no Node.js runtime, no compilation.

---

## Minimum Essential Commands

| Command | Description |
| :--- | :--- |
| `ai [prompt...]` | Ask a question (remembers conversation history) |
| `ai` | Launch interactive chat REPL |
| `echo "..." \| ai` | Pipe stdin into prompt (one-shot, skips history) |
| `ai -v` | **Toggle Voice Typing**: Inserts speech directly into focused window |
| `ai -V` | **Voice-to-Chat**: Speak your query -> transcribes and queries LLM |
| `ai -s [prompt...]` | Web search mode (Groq compound-mini) |
| `ai -n [prompt...]` | Start new conversation / clear history |
| `ai --status` | View session context tokens and message count |
| `ai --config` | Interactive setup for API key, models, and voice typing |

---

## Prerequisites

### Arch Linux / Omarchy
```bash
sudo pacman -S curl jq pipewire-audio wl-clipboard libnotify opus-tools wtype
```

| Tool | Purpose |
| :--- | :--- |
| `curl`, `jq` | Groq API HTTP requests and JSON processing |
| `pw-record` | Low-latency PipeWire microphone recording |
| `opusenc` | Compresses audio before upload (~1.9 MB WAV → ~100 KB Opus) |
| `wtype` | Types transcribed text directly into the focused application |
| `wl-copy` | Copies transcripts to Wayland system clipboard |
| `notify-send` | Desktop notifications (recording, transcribing, finished) |

---

## Installation

1. **Run the installer:**
   ```bash
   cd linux-setup/groq-ai
   ./apply_groq-ai.sh
   ```
   This installs `ai` into `~/.local/bin/ai`.

2. **Configure your API key:**
   ```bash
   ai --config
   ```
   *(Or set `export GROQ_API_KEY="your-api-key"` in your shell config).*

---

## Global Shortcut Setup (Omarchy / Hyprland)

To use voice typing from anywhere across the desktop:

1. Open your Omarchy keybindings file:
   ```bash
   nano ~/.config/hypr/bindings.lua
   # or
   nvim ~/.config/hypr/bindings.lua
   ```

2. Add this binding at the bottom:
   ```lua
   o.bind("ALT + L", "Groq Voice Typing", "/home/quantavil/.local/bin/ai -v")
   ```
   *(Or use `SUPER + H` if you prefer the standard voice typing shortcut).*

3. Reload Hyprland to apply:
   ```bash
   hyprctl reload
   ```

### How to use Voice Typing:
1. Place your cursor anywhere (browser address/search bar, Discord message, text editor).
2. Press `Alt + L` (or `Super + H`) → Desktop notification shows **"🎙 Recording Voice…"**.
3. Speak your thoughts.
4. Press the shortcut again → Audio is compressed and transcribed by Whisper. The text is automatically typed directly at your cursor and copied to your clipboard!

---

## Uninstallation

To remove Groq AI and optionally delete your configuration and history:
```bash
cd linux-setup/groq-ai
./revert_groq-ai.sh
```
