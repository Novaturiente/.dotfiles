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
