#!/bin/bash

# Check if an argument was provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 [up|down]"
    exit 1
fi

# Get current brightness percentage
current_percent=$(brightnessctl get)

# Determine adjustment step
if [ "$1" = "up" ]; then
    if [ "$current_percent" -gt 1920 ]; then
        swayosd-client --brightness +20
    else
        swayosd-client --brightness +1
    fi
elif [ "$1" = "down" ]; then
    if [ "$current_percent" -gt 1920 ]; then
        swayosd-client --brightness -20
    else
        swayosd-client --brightness -1
    fi
else
    echo "Invalid argument. Use 'up' or 'down'"
    exit 1
fi
