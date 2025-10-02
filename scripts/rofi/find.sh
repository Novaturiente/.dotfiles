#!/usr/bin/env bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SEARCH_DIRS=("$HOME/.dotfiles")

# Nerd Font icons (ensure your terminal uses a Nerd Font)
FOLDER_ICON="󰙅"  #
FILE_ICON="󱓧"    #

# Generate list with icons
ENTRIES=$(fd --type f --type d --hidden --follow . "${SEARCH_DIRS[@]}" | while read -r path; do
    if [[ -d "$path" ]]; then
        echo "${FOLDER_ICON} $path"
    else
        echo "${FILE_ICON} $path"
    fi
done)

ENTRIES="${FOLDER_ICON} $HOME/.dotfiles
$ENTRIES"

# Show in rofi
SELECTED=$(echo "$ENTRIES" | rofi -dmenu -i -p "󱎱 SEARCH" -theme "black.rasi")

# Exit if nothing selected
[[ -z "$SELECTED" ]] && exit 0

# Strip the icon (first 2 characters: icon + space)
SELECTED="${SELECTED:2}"

emacsclient -c "$SELECTED" &
