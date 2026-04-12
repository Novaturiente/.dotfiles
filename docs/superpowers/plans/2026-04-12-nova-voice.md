# Nova Voice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local voice input system that transcribes speech into active text fields and executes system commands via wake word, for Wayland/Niri.

**Architecture:** Python Vosk STT bridge streams transcribed text to a shell daemon. The daemon detects the "command" wake word, fuzzy-matches against a YAML command config, and injects text via ydotool or executes system actions via niri msg. Triggered by Mod+V keybinding (SIGUSR1 signal).

**Tech Stack:** Vosk (local STT), Python + sounddevice (audio capture), Bash (daemon), ydotool (text/key injection), niri msg (window actions), notify-send (feedback), systemd (service)

**Spec:** `docs/superpowers/specs/2026-04-12-nova-voice-design.md`

---

## File Structure

```
scripts/voice/
├── nova-voice.sh          # Main daemon — state machine, signal handling, routing
├── vosk-stream.py         # Python STT bridge — mic audio → text lines on stdout
├── commands.yaml          # Voice command mappings (key combos, spawn, niri actions)
├── setup.sh               # One-time setup — model download, service install
└── nova-voice.service     # Systemd user service definition
```

**Modified:**
- `nova/.config/niri/config.kdl` — add Mod+V keybinding

---

### Task 1: Create Project Directory and vosk-stream.py

**Files:**
- Create: `scripts/voice/vosk-stream.py`

- [ ] **Step 1: Create the scripts/voice directory**

```bash
mkdir -p /home/nova/.dotfiles/scripts/voice
```

- [ ] **Step 2: Create vosk-stream.py**

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["vosk", "sounddevice"]
# ///

"""Vosk streaming STT bridge. Captures mic audio, prints recognized text to stdout."""

import sys
import os
import json
import queue
import signal
import sounddevice as sd
from vosk import Model, KaldiRecognizer

SAMPLE_RATE = 16000
MODEL_PATH = os.path.expanduser("~/.local/share/vosk/model-en-small")

audio_queue = queue.Queue()

def audio_callback(indata, frames, time, status):
    if status:
        print(f"audio warning: {status}", file=sys.stderr)
    audio_queue.put(bytes(indata))

def main():
    # --check flag: verify model and deps exist, then exit
    if "--check" in sys.argv:
        if not os.path.isdir(MODEL_PATH):
            print(f"Model not found at {MODEL_PATH}", file=sys.stderr)
            sys.exit(1)
        Model(MODEL_PATH)
        print("vosk-stream: model and dependencies OK")
        sys.exit(0)

    if not os.path.isdir(MODEL_PATH):
        print(f"Error: Vosk model not found at {MODEL_PATH}", file=sys.stderr)
        print("Run setup.sh to download the model.", file=sys.stderr)
        sys.exit(1)

    model = Model(MODEL_PATH)
    recognizer = KaldiRecognizer(model, SAMPLE_RATE)

    # Exit cleanly on SIGTERM
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    # Unbuffered stdout so the shell daemon gets lines immediately
    sys.stdout.reconfigure(line_buffering=True)

    with sd.RawInputStream(
        samplerate=SAMPLE_RATE,
        blocksize=4000,
        dtype="int16",
        channels=1,
        callback=audio_callback,
    ):
        while True:
            data = audio_queue.get()
            if recognizer.AcceptWaveform(data):
                result = json.loads(recognizer.Result())
                text = result.get("text", "").strip()
                if text:
                    print(text, flush=True)

if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Make it executable**

```bash
chmod +x /home/nova/.dotfiles/scripts/voice/vosk-stream.py
```

- [ ] **Step 4: Verify syntax**

```bash
python3 -c "import ast; ast.parse(open('/home/nova/.dotfiles/scripts/voice/vosk-stream.py').read()); print('Syntax OK')"
```

Expected: `Syntax OK`

- [ ] **Step 5: Commit**

```bash
cd /home/nova/.dotfiles
git add scripts/voice/vosk-stream.py
git commit -m "feat(voice): add vosk-stream.py STT bridge"
```

---

### Task 2: Create commands.yaml

**Files:**
- Create: `scripts/voice/commands.yaml`

- [ ] **Step 1: Create commands.yaml with full default vocabulary**

```yaml
# === Key Combos ===
copy: { key: "ctrl+c" }
paste: { key: "ctrl+v" }
cut: { key: "ctrl+x" }
undo: { key: "ctrl+z" }
redo: { key: "ctrl+shift+z" }
save: { key: "ctrl+s" }
select all: { key: "ctrl+a" }
find: { key: "ctrl+f" }
close tab: { key: "ctrl+w" }
new tab: { key: "ctrl+t" }
enter: { key: "Return" }
tab: { key: "Tab" }
escape: { key: "Escape" }
space: { key: "Space" }
backspace: { key: "BackSpace" }

# === Text Editing ===
delete word: { key: "ctrl+BackSpace" }
delete line: { key: "ctrl+shift+k" }
go to end: { key: "ctrl+End" }
go to start: { key: "ctrl+Home" }
new line: { key: "Return" }
page up: { key: "Page_Up" }
page down: { key: "Page_Down" }

# === System Actions ===
open terminal: { spawn: "ghostty" }
close window: { niri: "close-window" }
fullscreen: { niri: "fullscreen-window" }
next workspace: { niri: "focus-workspace-down" }
previous workspace: { niri: "focus-workspace-up" }
move right: { niri: "focus-column-right" }
move left: { niri: "focus-column-left" }
screenshot: { spawn: "bash -c '~/.dotfiles/scripts/screenshot.sh'" }
```

- [ ] **Step 2: Commit**

```bash
cd /home/nova/.dotfiles
git add scripts/voice/commands.yaml
git commit -m "feat(voice): add default voice command mappings"
```

---

### Task 3: Create nova-voice.sh — Core Daemon

**Files:**
- Create: `scripts/voice/nova-voice.sh`

This is the main file. It handles signal-based toggling, reads vosk-stream output, routes to dictation or command execution.

- [ ] **Step 1: Create nova-voice.sh**

```bash
#!/usr/bin/env bash
# nova-voice: Voice input daemon for Wayland/Niri
# Triggered by SIGUSR1 (Mod+V keybinding)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_FILE="$SCRIPT_DIR/commands.yaml"
VOSK_STREAM="$SCRIPT_DIR/vosk-stream.py"
PIDFILE="/tmp/nova-voice-stream.pid"
export YDOTOOL_SOCKET="/run/user/$(id -u)/.ydotool_socket"

# --- State ---
STATE="idle"  # idle | recording | single-shot
LAST_SIGNAL_TIME=0
VOSK_PID=""

# --- Filler words to strip from command phrases ---
FILLER_WORDS="that|this|it|the|a|please|now|ok|okay|then|so|just"

# --- Notification helper ---
notify() {
    local msg="$1"
    local urgency="${2:-low}"
    local timeout="${3:-2000}"
    notify-send -u "$urgency" -t "$timeout" \
        -h string:x-dunst-stack-tag:nova-voice \
        "Nova Voice" "$msg"
}

# --- Key name to ydotool keycode mapping ---
declare -A KEYCODES=(
    [ctrl]=29 [shift]=42 [alt]=56 [super]=125
    [Return]=28 [Tab]=15 [Escape]=1 [BackSpace]=14
    [Delete]=111 [Home]=102 [End]=107 [Space]=57
    [Page_Up]=104 [Page_Down]=109
    [a]=30 [b]=48 [c]=46 [d]=32 [e]=18 [f]=33 [g]=34
    [h]=35 [i]=23 [j]=36 [k]=37 [l]=38 [m]=50 [n]=49
    [o]=24 [p]=25 [q]=16 [r]=19 [s]=31 [t]=20 [u]=22
    [v]=47 [w]=17 [x]=45 [y]=21 [z]=44
    [0]=11 [1]=2 [2]=3 [3]=4 [4]=5 [5]=6 [6]=7 [7]=8 [8]=9 [9]=10
)

# --- Convert human-readable key combo to ydotool key sequence ---
# e.g., "ctrl+c" -> "29:1 46:1 46:0 29:0"
keys_to_ydotool() {
    local combo="$1"
    local press="" release=""

    IFS='+' read -ra parts <<< "$combo"
    for key in "${parts[@]}"; do
        # Try original case first (for Return, Tab, BackSpace, etc.)
        local code="${KEYCODES[$key]:-}"
        if [[ -z "$code" ]]; then
            # Try lowercase (for ctrl, shift, alt, and letter keys)
            local lkey="${key,,}"
            code="${KEYCODES[$lkey]:-}"
        fi
        if [[ -z "$code" ]]; then
            echo "unknown key: $key" >&2
            return 1
        fi
        press+="${code}:1 "
        release="${code}:0 ${release}"
    done

    echo "${press}${release}"
}

# --- Parse commands.yaml into associative arrays ---
declare -A CMD_ACTIONS  # command_name -> action_type (key|spawn|niri)
declare -A CMD_VALUES   # command_name -> action_value
declare -a CMD_NAMES    # ordered list of command names

load_commands() {
    CMD_NAMES=()
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        # Parse "name: { type: value }"
        if [[ "$line" =~ ^([^:]+):[[:space:]]*\{[[:space:]]*(key|spawn|niri):[[:space:]]*\"([^\"]+)\" ]]; then
            local name="${BASH_REMATCH[1]}"
            local action_type="${BASH_REMATCH[2]}"
            local action_value="${BASH_REMATCH[3]}"
            # Trim whitespace from name
            name="$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            CMD_ACTIONS["$name"]="$action_type"
            CMD_VALUES["$name"]="$action_value"
            CMD_NAMES+=("$name")
        fi
    done < "$COMMANDS_FILE"
}

# --- Strip filler words from phrase ---
strip_fillers() {
    local phrase="$1"
    echo "$phrase" | sed -E "s/\b(${FILLER_WORDS})\b//gi" | sed 's/  */ /g;s/^ *//;s/ *$//'
}

# --- Levenshtein distance (pure bash, for short strings) ---
levenshtein() {
    local s="$1" t="$2"
    local s_len=${#s} t_len=${#t}
    local -a d

    for ((i = 0; i <= s_len; i++)); do d[$((i * (t_len + 1)))]=$i; done
    for ((j = 0; j <= t_len; j++)); do d[$j]=$j; done

    for ((i = 1; i <= s_len; i++)); do
        for ((j = 1; j <= t_len; j++)); do
            local cost=1
            [[ "${s:i-1:1}" == "${t:j-1:1}" ]] && cost=0
            local del=$((d[((i - 1) * (t_len + 1)) + j] + 1))
            local ins=$((d[(i * (t_len + 1)) + j - 1] + 1))
            local sub=$((d[((i - 1) * (t_len + 1)) + j - 1] + cost))
            local min=$del
            ((ins < min)) && min=$ins
            ((sub < min)) && min=$sub
            d[$((i * (t_len + 1) + j))]=$min
        done
    done
    echo "${d[$((s_len * (t_len + 1) + t_len))]}"
}

# --- Fuzzy match a phrase against commands ---
# Returns matched command name, or empty string
fuzzy_match() {
    local phrase="$1"
    local cleaned
    cleaned=$(strip_fillers "$phrase")
    cleaned="${cleaned,,}"  # lowercase

    # 1. Exact match
    for name in "${CMD_NAMES[@]}"; do
        [[ "${name,,}" == "$cleaned" ]] && echo "$name" && return
    done

    # 2. Substring match (phrase contains command or command contains phrase)
    for name in "${CMD_NAMES[@]}"; do
        local lname="${name,,}"
        [[ "$cleaned" == *"$lname"* ]] && echo "$name" && return
        [[ "$lname" == *"$cleaned"* ]] && echo "$name" && return
    done

    # 3. Levenshtein distance <= 2
    local best_name="" best_dist=999
    for name in "${CMD_NAMES[@]}"; do
        local dist
        dist=$(levenshtein "$cleaned" "${name,,}")
        if ((dist < best_dist)); then
            best_dist=$dist
            best_name="$name"
        fi
    done
    if ((best_dist <= 2)); then
        echo "$best_name"
        return
    fi

    # No match
    echo ""
}

# --- Execute a matched command ---
execute_command() {
    local name="$1"
    local action_type="${CMD_ACTIONS[$name]}"
    local action_value="${CMD_VALUES[$name]}"

    case "$action_type" in
        key)
            local ydotool_seq
            ydotool_seq=$(keys_to_ydotool "$action_value")
            if [[ -n "$ydotool_seq" ]]; then
                ydotool key $ydotool_seq
                notify "Voice: $name" low 1000
            fi
            ;;
        spawn)
            niri msg action spawn -- $action_value &
            notify "Voice: $name" low 1000
            ;;
        niri)
            niri msg action "$action_value"
            notify "Voice: $name" low 1000
            ;;
    esac
}

# --- Process a transcribed line ---
process_line() {
    local line="$1"
    [[ -z "$line" ]] && return

    # Check for wake word "command"
    if [[ "${line,,}" =~ ^command[[:space:]]+(.*) ]]; then
        local phrase="${BASH_REMATCH[1]}"
        local matched
        matched=$(fuzzy_match "$phrase")
        if [[ -n "$matched" ]]; then
            execute_command "$matched"
        else
            notify "Voice: unknown '$phrase'" normal 3000
        fi
    else
        # Dictation mode: type the text
        ydotool type --key-delay 2 -- "$line"
    fi
}

# --- Start recording ---
start_recording() {
    if [[ "$STATE" != "idle" ]]; then
        return
    fi
    STATE="recording"
    notify "Voice input active" low 2000

    # Start vosk-stream.py as background process
    uv run "$VOSK_STREAM" &
    VOSK_PID=$!
    echo "$VOSK_PID" > "$PIDFILE"
}

# --- Stop recording ---
stop_recording() {
    if [[ "$STATE" == "idle" ]]; then
        return
    fi

    if [[ -n "$VOSK_PID" ]] && kill -0 "$VOSK_PID" 2>/dev/null; then
        kill "$VOSK_PID" 2>/dev/null
        wait "$VOSK_PID" 2>/dev/null || true
    fi
    VOSK_PID=""
    rm -f "$PIDFILE"
    STATE="idle"
    notify "Voice input stopped" low 1000
}

# --- Signal handler for SIGUSR1 (toggle) ---
SIGNAL_RECEIVED=0
handle_signal() {
    SIGNAL_RECEIVED=1
}

# --- Cleanup on exit ---
cleanup() {
    stop_recording
    exit 0
}
trap cleanup EXIT SIGTERM SIGINT

# --- Main loop ---
main() {
    load_commands

    trap handle_signal USR1

    echo "nova-voice: daemon started (PID $$)"

    while true; do
        if [[ "$SIGNAL_RECEIVED" -eq 1 ]]; then
            SIGNAL_RECEIVED=0
            local now
            now=$(date +%s%N)

            if [[ "$STATE" == "idle" ]]; then
                # Check for double-press (single-shot mode)
                local elapsed=$(( (now - LAST_SIGNAL_TIME) / 1000000 ))
                LAST_SIGNAL_TIME=$now

                if ((elapsed < 300 && elapsed > 0)); then
                    # Double-press: single-shot mode
                    STATE="single-shot"
                    notify "Voice input (single-shot)" low 2000
                    local last_result_time=$now

                    uv run "$VOSK_STREAM" 2>/dev/null | while IFS= read -r line; do
                        process_line "$line"
                        last_result_time=$(date +%s%N)
                    done &
                    VOSK_PID=$!
                    echo "$VOSK_PID" > "$PIDFILE"

                    # Monitor for silence timeout (2 seconds)
                    (
                        sleep 2
                        while kill -0 "$VOSK_PID" 2>/dev/null; do
                            sleep 2
                        done
                    ) &
                    # Single-shot auto-stop is handled by vosk-stream's natural pauses
                    # For simplicity, single-shot runs until next SIGUSR1
                else
                    # Normal toggle on
                    start_vosk_and_process
                fi
            else
                # Toggle off
                stop_recording
            fi
        fi
        sleep 0.1
    done
}

# --- Start vosk and read its output ---
start_vosk_and_process() {
    STATE="recording"
    notify "Voice input active" low 2000

    # Pipe vosk-stream output through the process loop
    uv run "$VOSK_STREAM" 2>/dev/null | {
        while IFS= read -r line; do
            process_line "$line"
        done
    } &
    VOSK_PID=$!
    echo "$VOSK_PID" > "$PIDFILE"
}

main "$@"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x /home/nova/.dotfiles/scripts/voice/nova-voice.sh
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n /home/nova/.dotfiles/scripts/voice/nova-voice.sh && echo "Syntax OK"
```

Expected: `Syntax OK`

- [ ] **Step 4: Commit**

```bash
cd /home/nova/.dotfiles
git add scripts/voice/nova-voice.sh
git commit -m "feat(voice): add nova-voice.sh daemon with signal toggle, command routing, fuzzy matching"
```

---

### Task 4: Create setup.sh

**Files:**
- Create: `scripts/voice/setup.sh`

- [ ] **Step 1: Create setup.sh**

```bash
#!/usr/bin/env bash
# Nova Voice — one-time setup
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_DIR="$HOME/.local/share/vosk"
MODEL_URL="https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"

echo "=== Nova Voice Setup ==="

# 1. Download Vosk model
if [ ! -d "$MODEL_DIR/model-en-small" ]; then
    mkdir -p "$MODEL_DIR"
    echo "Downloading Vosk English model (~50MB)..."
    wget -q --show-progress "$MODEL_URL" -O /tmp/vosk-model.zip
    unzip -q /tmp/vosk-model.zip -d "$MODEL_DIR"
    mv "$MODEL_DIR"/vosk-model-small-en-us-* "$MODEL_DIR/model-en-small"
    rm /tmp/vosk-model.zip
    echo "Model installed to $MODEL_DIR/model-en-small"
else
    echo "Vosk model already installed."
fi

# 2. Verify Python deps + model
echo "Verifying vosk-stream..."
uv run "$SCRIPT_DIR/vosk-stream.py" --check

# 3. Verify ydotool is running
if [ ! -S "/run/user/$(id -u)/.ydotool_socket" ]; then
    echo "WARNING: ydotool socket not found. Ensure ydotoold is running."
    echo "  sudo systemctl enable --now ydotool"
fi

# 4. Install systemd service
mkdir -p "$HOME/.config/systemd/user"
cp "$SCRIPT_DIR/nova-voice.service" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now nova-voice.service

echo ""
echo "Nova Voice installed and running."
echo "Press Mod+V to toggle voice input."
echo "Say 'command <action>' for voice commands."
echo "Edit commands: $SCRIPT_DIR/commands.yaml"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x /home/nova/.dotfiles/scripts/voice/setup.sh
```

- [ ] **Step 3: Commit**

```bash
cd /home/nova/.dotfiles
git add scripts/voice/setup.sh
git commit -m "feat(voice): add setup.sh for one-time installation"
```

---

### Task 5: Create Systemd Service

**Files:**
- Create: `scripts/voice/nova-voice.service`

- [ ] **Step 1: Create nova-voice.service**

```ini
[Unit]
Description=Nova Voice Input Daemon
After=pipewire.service

[Service]
Type=simple
ExecStart=%h/.dotfiles/scripts/voice/nova-voice.sh
Restart=on-failure
RestartSec=3
Environment=YDOTOOL_SOCKET=/run/user/%U/.ydotool_socket

[Install]
WantedBy=default.target
```

- [ ] **Step 2: Commit**

```bash
cd /home/nova/.dotfiles
git add scripts/voice/nova-voice.service
git commit -m "feat(voice): add systemd user service"
```

---

### Task 6: Add Niri Keybinding

**Files:**
- Modify: `nova/.config/niri/config.kdl`

- [ ] **Step 1: Find the keybindings section in niri config**

```bash
grep -n "Mod+G\|Mod+V\|binds {" /home/nova/.dotfiles/nova/.config/niri/config.kdl | head -10
```

Find the section where other Mod+ keybindings are defined (near `Mod+G` for grammar fix).

- [ ] **Step 2: Add the Mod+V keybinding**

Add this line in the `binds { }` block, near the other custom keybindings:

```kdl
Mod+V { spawn "pkill" "-USR1" "-f" "nova-voice.sh"; }
```

Find the right location by looking near the `Mod+G` binding (grammar fix) and add it as a neighbor.

- [ ] **Step 3: Verify niri config is valid**

```bash
niri validate 2>&1 || echo "Check config syntax"
```

- [ ] **Step 4: Commit**

```bash
cd /home/nova/.dotfiles
git add nova/.config/niri/config.kdl
git commit -m "feat(voice): add Mod+V keybinding for voice input toggle"
```

---

### Task 7: Test End-to-End

**Files:** None (testing only)

- [ ] **Step 1: Download the Vosk model**

```bash
cd /home/nova/.dotfiles
bash scripts/voice/setup.sh
```

This downloads the model, verifies deps, installs the service.

- [ ] **Step 2: Verify the daemon is running**

```bash
systemctl --user status nova-voice.service
```

Expected: `active (running)`

- [ ] **Step 3: Verify the PID is accessible for signals**

```bash
pgrep -f "nova-voice.sh"
```

Expected: outputs a PID number

- [ ] **Step 4: Test vosk-stream.py standalone**

Open a terminal and run:

```bash
uv run /home/nova/.dotfiles/scripts/voice/vosk-stream.py
```

Speak into the microphone. Text should appear on stdout. Press Ctrl+C to stop.

- [ ] **Step 5: Test the toggle**

```bash
pkill -USR1 -f "nova-voice.sh"
```

Expected: notification "Voice input active" appears. Speak — text should be typed into the active text field.

Send SIGUSR1 again to stop:

```bash
pkill -USR1 -f "nova-voice.sh"
```

Expected: notification "Voice input stopped" appears.

- [ ] **Step 6: Test voice commands**

While recording is active, say "command copy". Expected: Ctrl+C is triggered, notification "Voice: copy" appears.

Say "command open terminal". Expected: Ghostty opens.

Say "command that doesn't exist". Expected: notification "Voice: unknown '...'" appears.

- [ ] **Step 7: Test fuzzy matching**

Say "command copy that please". Expected: still triggers copy (filler words stripped).

Say "command coppy" (slight mispronunciation). Expected: still matches "copy" via Levenshtein (distance 1).

- [ ] **Step 8: Test Mod+V keybinding**

Press Mod+V on keyboard. Expected: same as sending SIGUSR1 — recording toggles.

- [ ] **Step 9: Commit any fixes from testing**

```bash
cd /home/nova/.dotfiles
git add -A scripts/voice/
git commit -m "fix(voice): post-testing adjustments"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | vosk-stream.py (Python STT bridge) | `scripts/voice/vosk-stream.py` |
| 2 | commands.yaml (voice command mappings) | `scripts/voice/commands.yaml` |
| 3 | nova-voice.sh (main daemon) | `scripts/voice/nova-voice.sh` |
| 4 | setup.sh (one-time install) | `scripts/voice/setup.sh` |
| 5 | systemd service | `scripts/voice/nova-voice.service` |
| 6 | Niri keybinding | `nova/.config/niri/config.kdl` |
| 7 | End-to-end testing | (manual verification) |
