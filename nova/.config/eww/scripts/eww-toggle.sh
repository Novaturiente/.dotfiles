#!/usr/bin/env bash
# Toggle eww widget with auto-close on focus loss
set -euo pipefail

WIDGET="$1"
FOCUS_PID_FILE="/tmp/eww-focus-$WIDGET.pid"

# Kill any existing focus watcher
if [[ -f "$FOCUS_PID_FILE" ]]; then
    kill "$(<"$FOCUS_PID_FILE")" 2>/dev/null || true
    rm -f "$FOCUS_PID_FILE"
fi

# Check if widget is currently open
if eww active-windows 2>/dev/null | grep -q "$WIDGET"; then
    eww close "$WIDGET"
    exit 0
fi

# Open the widget
eww open "$WIDGET"

# Spawn focus watcher — closes widget when focus leaves eww
(
    sleep 0.3  # Wait for widget to appear and gain focus
    while true; do
        sleep 0.2
        app_id=$(niri msg focused-window 2>/dev/null | grep "App ID:" | sed 's/.*App ID: "\(.*\)"/\1/' || echo "")
        if [[ "$app_id" != "eww"* && "$app_id" != "" ]]; then
            eww close "$WIDGET" 2>/dev/null
            rm -f "$FOCUS_PID_FILE"
            exit 0
        fi
        # Also exit if widget was closed by other means
        if ! eww active-windows 2>/dev/null | grep -q "$WIDGET"; then
            rm -f "$FOCUS_PID_FILE"
            exit 0
        fi
    done
) &
echo $! > "$FOCUS_PID_FILE"
