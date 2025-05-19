#!/bin/bash

# Script to cycle through power profiles and display notifications using swaync

# Define the known power profiles in order
PROFILES=("power-saver" "balanced" "performance")

# Get current active profile
current_profile=$(powerprofilesctl get)
echo "Current profile: $current_profile"

# Find the index of the current profile
current_index=-1
for i in "${!PROFILES[@]}"; do
    if [[ "${PROFILES[$i]}" == "$current_profile" ]]; then
        current_index=$i
        break
    fi
done

# If current profile not found in our list, default to the first profile
if [[ $current_index -eq -1 ]]; then
    next_profile="${PROFILES[0]}"
else
    # Calculate the next profile index (circular)
    next_index=$(( (current_index + 1) % ${#PROFILES[@]} ))
    next_profile="${PROFILES[$next_index]}"
fi

echo "Switching to profile: $next_profile"

# Switch to the next profile
powerprofilesctl set "$next_profile"

# Get a user-friendly description for the notification
case "$next_profile" in
    "power-saver")
        description="Power Saver Mode (Optimized for battery life)"
        icon="battery-low"
        ;;
    "balanced")
        description="Balanced Mode (Default performance)"
        icon="battery"
        ;;
    "performance")
        description="Performance Mode (Maximum performance)"
        icon="battery-good"
        ;;
    *)
        description="$next_profile"
        icon="battery"
        ;;
esac

# Send notification with swaync
notify-send "Power Profile Changed" "Now using: $description" --icon="$icon" --app-name="Power Profiles Daemon"

echo "Changed power profile to: $next_profile"
exit 0
