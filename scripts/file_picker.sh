#!/usr/bin/env bash

# 1. Open Zenity File Picker
# --file-selection: Transformation mode
# --title: Window title
# --multiple: allow several files, one path per line
FILE_PATHS=$(zenity --file-selection --multiple --separator=$'\n' --title="Select Files to Attach")

# 2. Check if user cancelled (Empty path)
if [ -z "$FILE_PATHS" ]; then
	exit 0
fi

# 3. Copy to Clipboard as a "File Object"
# Chat apps (Discord/Slack) expect a 'text/uri-list' MIME type
# We must prepend 'file://' to each path; uri-list lines end in CRLF
sed 's|^|file://|; s|$|\r|' <<<"$FILE_PATHS" | wl-copy -t text/uri-list

# 4. Simulate Paste (Ctrl+V)
# We wait 0.2s to ensure the window focus has returned to your app
sleep 0.2
ydotool key 29:1 47:1 47:0 29:0
