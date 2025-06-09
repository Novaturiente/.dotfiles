#!/usr/bin/env bash

# Efficient Waybar toggle script based on windows in the **current workspace only**
# Requires: hyprctl, jq, and Waybar handling SIGUSR1 (show) and SIGUSR2 (hide)

last_window_count=-1

check_current_workspace_windows() {
    # Get current active workspace ID
    active_ws=$(hyprctl activeworkspace -j | jq -r '.id')

    # Count number of windows in the current workspace only
    window_count=$(hyprctl clients -j | jq --argjson ws "$active_ws" '
	map(select(.workspace.id == $ws)) | length')

    # Only act if the number of windows has changed
    if [[ "$window_count" -ne "$last_window_count" ]]; then
	if [[ "$window_count" > 0 ]]; then
	    pkill -USR2 waybar  # Show Waybar
	else
	    pkill -USR1 waybar  # Hide Waybar
	fi
	last_window_count=$window_count
    fi
}

# Initial check at startup
check_current_workspace_windows

# Listen to workspace and window events
hyprctl --batch 'subscribeevent workspace;subscribeevent window' | while read -r _; do
    check_current_workspace_windows
done
