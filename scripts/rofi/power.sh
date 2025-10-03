#!/usr/bin/env bash

# Options for Rofi
options=("󰍃  Logout" "  Shutdown" "󰜉  Reboot")

# Show Rofi menu
selected=$(printf '%s\n' "${options[@]}" | rofi -dmenu -p "󰮫 " -theme power)

# Execute the selected action
case "$selected" in
    "  Shutdown")
        confirm=$(echo -e "Yes\nNo" | rofi -dmenu -p "Shutdown?" -theme power)
	[[ "$confirm" == "Yes" ]] && systemctl poweroff
        ;;
    "󰜉  Reboot")
        confirm=$(echo -e "Yes\nNo" | rofi -dmenu -p "Reboot?" -theme power)
        [[ "$confirm" == "Yes" ]] && systemctl reboot
        ;;
    "󰍃  Logout")
        confirm=$(echo -e "Yes\nNo" | rofi -dmenu -p "Logout?" -theme power)
	[[ "$confirm" == "Yes" ]] && loginctl terminate-user "$USER"
        ;;
 
esac
