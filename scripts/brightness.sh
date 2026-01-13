#!/usr/bin/env bash

# Check if an argument was provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 [up|down]"
    exit 1
fi

# Get current brightness percentage
current_percent=$(brightnessctl get)

# Determine adjustment step
if [ "$1" = "up" ]; then
    if [ "$current_percent" -gt 1728 ]; then
        dms ipc call brightness increment 5 backlight:intel_backlight
    else
        dms ipc call brightness increment 1 backlight:intel_backlight
    fi
elif [ "$1" = "down" ]; then
    if [ "$current_percent" -gt 1920 ]; then
        dms ipc call brightness decrement 5 backlight:intel_backlight
    else
        dms ipc call brightness decrement 1 backlight:intel_backlight
    fi
else
    echo "Invalid argument. Use 'up' or 'down'"
    exit 1
fi
