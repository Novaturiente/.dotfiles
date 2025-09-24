#!/usr/bin/env bash

# Set initial directory (can be modified)
DIR="${1:-$HOME}"

killall castnow

# Use find to list files and directories, pipe to rofi
SELECTED=$(find "$DIR" -type d -name '.*' -prune -o -type f -print 2>/dev/null | rofi -dmenu -i -p "Select a file:")

# Print the selected file if not empty
if [[ -n "$SELECTED" ]]; then
    castnow "$SELECTED"
else
    echo "No file selected."
fi
