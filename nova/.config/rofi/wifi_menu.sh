#!/bin/bash

# Check if WiFi is enabled
wifi_status=$(nmcli radio wifi)

# First option: Toggle WiFi
options="Toggle WiFi: $wifi_status\n"

# Get available networks (with signal strength, removing duplicates)
if [ "$wifi_status" = "enabled" ]; then
    networks=$(nmcli -t -f SSID,SECURITY,SIGNAL dev wifi list | \
               awk -F: '!seen[$1]++ {print $1 " " $3 "% " $2}' | \
               sort -k2 -nr)  # Sort by signal strength
    options+="$networks"
fi

# Show Rofi menu
choice=$(echo -e "$options" | rofi -dmenu -theme wifi-menu -p "WiFi" -format 's')

if [ -z "$choice" ]; then
    exit 0
fi

# Handle selection
case "$choice" in
    "Toggle WiFi: enabled")
        nmcli radio wifi off
        notify-send "WiFi" "WiFi turned off"
        ;;
    "Toggle WiFi: disabled")
        nmcli radio wifi on
        notify-send "WiFi" "WiFi turned on"
        ;;
    *)
        # Extract SSID (first field) and security (last field)
        ssid=$(echo "$choice" | awk '{print $1}')
        security=$(echo "$choice" | awk '{print $NF}')

        # Check if network is already saved
        if nmcli -t -g NAME con show | grep -q "^$ssid$"; then
            nmcli con up "$ssid"
        else
            # Handle secured networks
            if [[ "$security" == "WPA"* ]] || [[ "$security" == "WEP"* ]]; then
                password=$(rofi -dmenu -p "Password for $ssid" -password -lines 0)
                [ -z "$password" ] && exit 1
                nmcli dev wifi connect "$ssid" password "$password"
            else
                nmcli dev wifi connect "$ssid"
            fi
        fi

        # Connection result notification
        if [ $? -eq 0 ]; then
            notify-send "WiFi" "Connected to $ssid"
        else
            notify-send "WiFi" "Failed to connect to $ssid" --icon=error
        fi
        ;;
esac
