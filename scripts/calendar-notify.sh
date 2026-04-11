#!/bin/bash

# Required for notifications to reach your desktop from 'at'
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus

PRE_WARNING=10

# Get today's events, specifically skipping the "Today, 25/03/2026" header
khal list today --format "{start-time} {title}" | while read -r line; do

	# Check if the line starts with a time (e.g., 01:00 PM)
	# This regex handles both 24h and 12h formats
	if [[ ! $line =~ ^[0-9]{2}:[0-9]{2} ]]; then
		continue
	fi

	EVENT_TIME=$(echo "$line" | awk '{print $1" "$2}')
	EVENT_TITLE=$(echo "$line" | cut -d' ' -f3-)

	# Calculate notification time
	NOTIFY_TIME=$(date --date="$EVENT_TIME $PRE_WARNING minutes ago" +%H:%M 2>/dev/null)

	# Schedule with 'at' - including the environment variables for the job
	echo "export DISPLAY=:0; export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus; notify-send -u critical 'Meeting Soon: $EVENT_TITLE' 'Starts at $EVENT_TIME'" | at "$NOTIFY_TIME" today 2>/dev/null

done
