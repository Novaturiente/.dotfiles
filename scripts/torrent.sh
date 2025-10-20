#!/usr/bin/env bash
#
# File: torrent.sh
# Author: nova
# Created: 2025-10-19 10:44:08

# Start deluged daemon in background
deluged &

# Give daemon some time to start
sleep 2

# Run deluge-console
deluge-console

# After console exits, kill the daemon
killall deluged
