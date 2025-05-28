#!/usr/bin/env bash

# Get the active workspace
active_workspace=$(hyprctl activeworkspace -j | jq -r '.id')

# Check if there are any windows in the active workspace
window_count=$(hyprctl clients -j | jq --argjson ws "$active_workspace" 'map(select(.workspace.id == $ws)) | length')

if [[ "$window_count" -eq 0 ]]; then
    # No windows, show Waybar
    waybar  # Assuming Waybar supports SIGUSR1 to show
else
    # Windows present, hide Waybar
    killall waybar  # Assuming Waybar supports SIGUSR2 to hide
fi
