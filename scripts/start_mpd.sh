#!/bin/bash

# Check if MPD is running
if pgrep -x "mpd" > /dev/null; then
    # Kill MPD if running
    killall mpd
    notify-send "MPD Stopped" "Music Player Daemon has been terminated" --icon=media-playback-stop
else
    # Start MPD if not running
    mpd --no-daemon ~/.config/mpd/mpd.conf &
    notify-send "MPD Started" "Music Player Daemon is now running" --icon=media-playback-start
fi
