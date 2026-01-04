#!/usr/bin/env bash

# Get list of active tmux sessions
SESSIONS=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)

# Show rofi menu with existing sessions
SELECTED=$(echo "$SESSIONS" | rofi -dmenu -i -p "󰆍 TMUX" -theme "black")

# Exit if nothing selected
[[ -z "$SELECTED" ]] && exit 0

# Check if session exists
if tmux has-session -t "$SELECTED" 2>/dev/null; then
    # Session exists, attach to it in a new ghostty window
    ghostty -e tmux attach-session -t "$SELECTED"
else
    # Session doesn't exist, create it and attach in a new ghostty window
    ghostty -e tmux new-session -s "$SELECTED"
fi

