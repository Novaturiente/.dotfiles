#!/usr/bin/env bash

# Show Rofi input prompt for URL
url=$(rofi -dmenu -theme tokyonight -p "URL :")

notify-send "Download added"
/home/nova/.local/bin/aria2p add "$url"

kitty -T "aria2p" -e aria2p
