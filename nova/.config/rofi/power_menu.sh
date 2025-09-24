#!/usr/bin/env bash

# Options for Rofi
options=("󰍃  Logout" "  Shutdown" "󰜉  Reboot")

# Show Rofi menu
selected=$(printf '%s\n' "${options[@]}" | rofi -dmenu -p "Power Menu:" -theme power-menu)

# Execute the selected action
case "$selected" in
    "  Shutdown")
        confirm=$(echo -e "Yes\nNo" | rofi -dmenu -p "Shutdown?" -theme power-menu)
	[[ "$confirm" == "Yes" ]] && systemctl poweroff
        ;;
    "󰜉  Reboot")
        confirm=$(echo -e "Yes\nNo" | rofi -dmenu -p "Reboot?" -theme power-menu)
        [[ "$confirm" == "Yes" ]] && systemctl reboot
        ;;
    "󰍃  Logout")
        confirm=$(echo -e "Yes\nNo" | rofi -dmenu -p "Logout?" -theme power-menu)
	[[ "$confirm" == "Yes" ]] && loginctl terminate-user "$USER"
        ;;
 
esac
