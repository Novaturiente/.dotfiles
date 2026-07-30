#!/usr/bin/env bash

# Rofi window switcher for niri
# Shows [App Name] Window Title, with tmux session detection for Ghostty

# --- App name mapping ---
get_app_name() {
    local app_id="$1"
    case "$app_id" in
        com.mitchellh.ghostty)       echo "Ghostty" ;;
        zen)                         echo "Zen Browser" ;;
        org.qutebrowser.qutebrowser) echo "Qutebrowser" ;;
        google-chrome)               echo "Chrome" ;;
        thorium-browser)             echo "Thorium" ;;
        org.kde.dolphin)             echo "Dolphin" ;;
        neovide)                     echo "Neovide" ;;
        *)
            # Extract last dot-separated segment, capitalize first letter
            local last="${app_id##*.}"
            echo "${last^}"
            ;;
    esac
}

# --- Tmux session detection ---
# Given a ghostty PID, check if it's running tmux and return the session name
get_tmux_session() {
    local window_pid="$1"
    local child_pid child_comm

    child_pid=$(pgrep -P "$window_pid" 2>/dev/null | head -1)
    [[ -z "$child_pid" ]] && return 1

    child_comm=$(ps -o comm= -p "$child_pid" 2>/dev/null)
    [[ "$child_comm" != "tmux: client" ]] && return 1

    tmux list-clients -F '#{client_pid}:#{session_name}' 2>/dev/null \
        | awk -F: -v pid="$child_pid" '$1 == pid { print $2; exit }'
}

# --- Main ---

# Get all windows as JSON, filter out focused, sort by workspace
windows_json=$(niri msg -j windows)

# Build entries
declare -A id_map     # display_string -> window_id
declare -A seen_count # display_string -> count (for dedup)
entries=""

while IFS= read -r line; do
    win_id=$(echo "$line" | jq -r '.id')
    app_id=$(echo "$line" | jq -r '.app_id')
    title=$(echo "$line" | jq -r '.title')
    pid=$(echo "$line" | jq -r '.pid')

    app_name=$(get_app_name "$app_id")

    # Tmux detection for Ghostty
    display_name="$title"
    if [[ "$app_id" == "com.mitchellh.ghostty" ]]; then
        session=$(get_tmux_session "$pid")
        if [[ -n "$session" ]]; then
            display_name="$session"
        fi
    fi

    entry="[$app_name] $display_name"

    # Handle duplicate display strings
    if [[ -n "${id_map[$entry]}" ]]; then
        count=${seen_count[$entry]:-1}
        count=$((count + 1))
        seen_count[$entry]=$count
        entry="$entry ($count)"
    fi

    id_map["$entry"]=$win_id

    if [[ -n "$entries" ]]; then
        entries="$entries"$'\n'"$entry"
    else
        entries="$entry"
    fi
done < <(echo "$windows_json" | jq -c 'sort_by(.workspace_id) | .[] | select(.is_focused == false)')

# Exit silently if no windows
[[ -z "$entries" ]] && exit 0

# Show rofi
selected=$(echo "$entries" | rofi -dmenu -i -p "󰖯 " -theme "black.rasi")

# Exit if user cancelled
[[ -z "$selected" ]] && exit 0

# Focus the selected window
win_id="${id_map[$selected]}"
[[ -n "$win_id" ]] && niri msg action focus-window --id "$win_id"
