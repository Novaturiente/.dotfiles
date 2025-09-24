#!/usr/bin/env sh

#!/bin/bash

# Check if swayidle is running
if pgrep -x swayidle >/dev/null; then
    echo "swayidle is running, killing it..."
    pkill swayidle
    notify-send "Idle disabled"
else
    echo "swayidle is not running, starting it..."

    # Start swayidle with your preferred configuration
    # Customize the parameters below for your setup
    swayidle -w \
        timeout 300 'swaylock -f' \
        timeout 600 'wlopm --off "*"' \
        resume 'wlopm --on "*"' \
        before-sleep 'swaylock -f' &

    notify-send "Idle enabled"
fi
