#!/usr/bin/env bash
declare -A map=(
  ["󰏔  packages"]="emacsclient -c -a '' ~/.dotfiles/system/package"
  ["󱂵  dotfiles"]="emacsclient -c -a '' ~/.dotfiles"
  ["  configs"]="emacsclient -c -a '' ~/.dotfiles/nova/.config"
  ["󰠮  Notes"]="emacsclient -c -a '' ~/Org"
)

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Show keys
choice="$(printf '%s\n' "${!map[@]}" | sort | rofi -dmenu -p "Select Folder" -theme "$SCRIPT_DIR/nord.rasi")"

# Exit if nothing selected
[ -z "$choice" ] && exit 0

# Extract path from the command
command="${map[$choice]}"
current_path="${command##* }"  # Get last argument
current_path="${current_path/#\~/$HOME}"  # Expand tilde

# Navigate through directories
while true
do
  if [ -d "$current_path" ]; then
    # Get list with icons for display
    display_list="$(eza --icons=always -1 "$current_path")"

    # Get clean filenames for actual paths
    clean_list="$(eza -1 "$current_path")"

    # Show rofi with icons
    selected_display="$(echo "$display_list" | rofi -dmenu -p "Select Item" -theme "$SCRIPT_DIR/nord.rasi")"

    [ -z "$selected_display" ] && exit 0

    # Find the line number of selection
    line_num="$(echo "$display_list" | grep -n "^${selected_display}$" | cut -d: -f1)"

    # Get corresponding clean filename
    new_choice="$(echo "$clean_list" | sed -n "${line_num}p")"

    current_path="$current_path/$new_choice"

  elif [ -f "$current_path" ]; then
    emacsclient -c -a '' "$current_path"
    exit 0
  else
    echo "Error: '$current_path' does not exist" >&2
    exit 1
  fi
done
