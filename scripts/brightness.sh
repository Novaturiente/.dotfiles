#!/usr/bin/env bash

# Check if an argument was provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 [up|down]"
    exit 1
fi

# Get current brightness percentage
current_percent=$(brightnessctl -m | cut -d, -f4 | tr -d %)
# Fine 1% steps at or below this, 5% steps above (same for both directions)
THRESHOLD=35

# Determine adjustment step
if [ "$1" = "up" ]; then
    if [ "$current_percent" -ge "$THRESHOLD" ]; then
        brightnessctl set +5%
    else
        brightnessctl set +1%
    fi
elif [ "$1" = "down" ]; then
    if [ "$current_percent" -gt "$THRESHOLD" ]; then
        brightnessctl set 5%-
    else
        brightnessctl set 1%-
    fi
else
    echo "Invalid argument. Use 'up' or 'down'"
    exit 1
fi
