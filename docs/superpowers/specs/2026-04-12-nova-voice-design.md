# Nova Voice — Voice Input & Command System

**Date:** 2026-04-12
**Status:** Draft
**Approach:** Shell daemon + Python Vosk STT bridge, local-only, streaming

## Overview

A voice input system for Wayland/Niri that transcribes speech into the active text field and executes system commands via voice. Fully local (no cloud), streaming transcription via Vosk, text injection via ydotool, configurable command vocabulary with fuzzy matching.

## Architecture

Three layers:

```
┌─────────────────────────────────┐
│  Niri keybinding (Mod+V)        │  trigger layer
│  sends SIGUSR1 to daemon        │
├─────────────────────────────────┤
│  nova-voice.sh (shell daemon)   │  control layer
│  state machine, command routing, │
│  fuzzy matching, ydotool inject  │
├─────────────────────────────────┤
│  vosk-stream.py (Python)        │  STT layer
│  pw mic → Vosk → stdout lines   │
└─────────────────────────────────┘
```

### File Structure

```
scripts/voice/
├── nova-voice.sh          # Main daemon (shell)
├── vosk-stream.py         # Python STT bridge (~50 lines)
├── commands.yaml          # Voice command mappings
├── setup.sh               # One-time setup (model download, deps, enable service)
└── nova-voice.service     # Systemd user service
```

## 1. STT Layer — vosk-stream.py

Minimal Python script. Single responsibility: microphone audio to text on stdout.

**Behavior:**
- Opens default PipeWire microphone via `sounddevice` library
- Feeds 16kHz mono audio chunks to Vosk
- Prints each final recognized phrase to stdout as a plain text line
- Ignores partial results (only final results for reliability)
- Exits cleanly on SIGTERM or when parent process dies

**Output format:** One line per recognized phrase, plain text, no JSON:
```
hello world
command copy
this is a test sentence
```

**Dependencies:**
- `vosk` Python package (includes C library)
- `sounddevice` Python package (uses PortAudio, works with PipeWire)
- Vosk English small model (~50MB) at `~/.local/share/vosk/model-en-small`

**Install method:** PEP 723 inline script dependencies so `uv run vosk-stream.py` handles the virtualenv automatically:
```python
# /// script
# dependencies = ["vosk", "sounddevice"]
# ///
```

## 2. Control Layer — nova-voice.sh

Shell daemon that manages state, reads transcription from vosk-stream.py, and routes to dictation or command execution.

### States

| State | Description | vosk-stream running? |
|-------|-------------|---------------------|
| **Idle** | Waiting for keybind signal | No |
| **Recording** | Transcribing speech → typing text | Yes |
| **Command** | Wake word detected, next phrase is a command | Yes (same session) |

### Trigger Modes

Niri keybinding sends SIGUSR1 to the daemon. The daemon implements:

- **Toggle:** First SIGUSR1 starts recording, next SIGUSR1 stops it
- **Single-shot (double-press):** Two SIGUSR1 within 300ms enters single-shot mode — records until no new Vosk final result arrives for 2 seconds (checked via timestamp of last output line), then auto-stops

### Recording Flow

1. SIGUSR1 received → start vosk-stream.py as subprocess
2. Send notification: "Voice input active"
3. Read stdout lines from vosk-stream.py in a loop
4. For each line:
   - If line starts with "command " → enter command mode, extract phrase after "command", match and execute
   - Otherwise → inject text via ydotool
5. On SIGUSR1 again (or silence in single-shot mode) → kill vosk-stream.py, send notification: "Voice input stopped"

### Wake Word

The wake word is "command". When Vosk transcribes a line starting with "command", the remainder is treated as a command phrase:

```
"command copy"          → command phrase: "copy"
"command open terminal" → command phrase: "open terminal"
"hello world"           → dictation: types "hello world"
```

The wake word can appear at any point during a recording session. The system doesn't need a separate command mode keybind — just say "command" before your instruction.

## 3. Command Matching

### commands.yaml Format

```yaml
# Key combos
copy: { key: "ctrl+c" }
paste: { key: "ctrl+v" }
cut: { key: "ctrl+x" }
undo: { key: "ctrl+z" }
redo: { key: "ctrl+shift+z" }
save: { key: "ctrl+s" }
select all: { key: "ctrl+a" }
find: { key: "ctrl+f" }
enter: { key: "Return" }
tab: { key: "Tab" }
escape: { key: "Escape" }

# Text editing
delete word: { key: "ctrl+BackSpace" }
delete line: { key: "ctrl+shift+k" }
go to end: { key: "ctrl+End" }
go to start: { key: "ctrl+Home" }
new line: { key: "Return" }

# System actions
open terminal: { spawn: "ghostty" }
close window: { niri: "close-window" }
switch workspace: { niri: "focus-workspace-down" }
next workspace: { niri: "focus-workspace-down" }
previous workspace: { niri: "focus-workspace-up" }
screenshot: { spawn: "~/.dotfiles/scripts/screenshot.sh" }
fullscreen: { niri: "fullscreen-window" }
```

### Action Types

| Type | Execution | Example |
|------|-----------|---------|
| `key` | ydotool key sequence | `ctrl+c` → `ydotool key 29:1 46:1 46:0 29:0` |
| `spawn` | Launch program via niri | `niri msg action spawn -- ghostty` |
| `niri` | Niri window management action | `niri msg action close-window` |

### Fuzzy Matching

1. **Strip filler words** from the spoken phrase before matching. Filler list: `that`, `this`, `it`, `the`, `a`, `please`, `now`, `ok`, `then`
   - "copy that please" → "copy" → matches `copy`
   - "open the terminal now" → "open terminal" → matches `open terminal`

2. **Exact match first** — case-insensitive string match against command keys

3. **Substring match** — if no exact match, check if any command key is contained in the phrase or vice versa

4. **Levenshtein fallback** — if still no match, find the closest command within edit distance ≤ 2 (using `awk` or a small shell function). This handles minor Vosk misrecognitions.

5. **No match** → notification: "Voice: unknown command '<phrase>'"

## 4. Text Injection

**Dictation text:** Injected via `ydotool type --key-delay 2 "<text>"`. The 2ms delay between keystrokes prevents dropped characters.

**Key combos:** Converted from human-readable format to ydotool keycodes:

| Key name | ydotool keycode |
|----------|----------------|
| ctrl | 29 |
| shift | 42 |
| alt | 56 |
| super | 125 |
| Return | 28 |
| Tab | 15 |
| Escape | 1 |
| BackSpace | 14 |
| Delete | 111 |
| Home | 102 |
| End | 107 |
| a-z | 30-52 (varies) |

The daemon includes a keyname-to-keycode mapping function. `ctrl+c` becomes `ydotool key 29:1 46:1 46:0 29:0`.

## 5. Notifications

All via `notify-send` with stack tag to prevent notification pileup:

| Event | Message | Urgency | Timeout |
|-------|---------|---------|---------|
| Recording started | "Voice input active" | low | 2s |
| Recording stopped | "Voice input stopped" | low | 1s |
| Command executed | "Voice: copy" | low | 1s |
| Unknown command | "Voice: unknown '<phrase>'" | normal | 3s |
| Error | "Voice error: <msg>" | critical | 5s |

Stack tag: `--hint string:x-dunst-stack-tag:nova-voice` (works with most notification daemons).

## 6. Systemd Service

```ini
[Unit]
Description=Nova Voice Input Daemon
After=pipewire.service

[Service]
Type=simple
ExecStart=%h/.dotfiles/scripts/voice/nova-voice.sh
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
```

Daemon starts at login, idles with negligible resource usage (~1MB shell process). Vosk model only loads when recording starts (on first SIGUSR1).

## 7. Niri Keybinding

Added to `nova/.config/niri/config.kdl`:

```kdl
Mod+V { spawn "pkill" "-USR1" "-f" "nova-voice.sh"; }
```

## 8. First-Time Setup (setup.sh)

```bash
#!/usr/bin/env bash
set -e

MODEL_DIR="$HOME/.local/share/vosk"
MODEL_URL="https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"

# Download Vosk model
if [ ! -d "$MODEL_DIR/model-en-small" ]; then
    mkdir -p "$MODEL_DIR"
    echo "Downloading Vosk English model..."
    wget -q "$MODEL_URL" -O /tmp/vosk-model.zip
    unzip -q /tmp/vosk-model.zip -d "$MODEL_DIR"
    mv "$MODEL_DIR"/vosk-model-small-en-us-* "$MODEL_DIR/model-en-small"
    rm /tmp/vosk-model.zip
    echo "Model installed to $MODEL_DIR/model-en-small"
fi

# Verify Python deps work
uv run scripts/voice/vosk-stream.py --check

# Install systemd service
cp scripts/voice/nova-voice.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now nova-voice.service

echo "Nova Voice installed and running. Press Mod+V to start dictating."
```

## Dependencies

**System packages** (add to base-system.yaml or development.yaml):
- `python` (already installed)
- `uv` (already installed)
- `ydotool` (already in windowmanager.yaml)

**Python packages** (managed by uv, PEP 723 inline):
- `vosk`
- `sounddevice`

**External download:**
- Vosk model: `vosk-model-small-en-us-0.15` (~50MB)

## NPU Future Path

The architecture is designed for future NPU offloading:
- Wake word detection is a separate concern (currently: string prefix match on "command")
- Can be replaced with a dedicated wake word model (openWakeWord/Porcupine) running on Intel NPU via OpenVINO
- The daemon's interface doesn't change — wake word detection just becomes a different code path in the same read loop
- Intel NPU driver (`intel-npu-driver-bin`) is already installed

## Non-Goals

- Cloud/API-based STT
- Multiple language support
- GUI configuration
- Continuous always-listening mode (only listens when toggled on)
- Training custom voice models
