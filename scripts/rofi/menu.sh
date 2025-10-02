#!/usr/bin/env bash
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

declare -A map=(
  ["  Folders"]="$SCRIPT_DIR/folders.sh"
  ["  Files"]="$SCRIPT_DIR/files.sh"
)


# Show keys
choice="$(printf '%s\n' "${!map[@]}" | sort | rofi -dmenu -p "Select Folder" -theme "$SCRIPT_DIR/nord.rasi")"

# Run the corresponding value
[ -n "$choice" ] && eval "${map[$choice]}"                                 # eval to allow arguments/quotes [web:28][web:20]
