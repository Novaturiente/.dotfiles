#!/usr/bin/env bash
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

"$SCRIPT_DIR"/cliphist-rofi-img.sh | rofi -dmenu -display-columns 2 -p " "| cliphist decode | wl-copy
