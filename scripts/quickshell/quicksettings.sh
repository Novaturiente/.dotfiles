#!/usr/bin/env bash
# Toggle the Quickshell quick settings panel (wifi, bluetooth, audio, battery).
# Starts the daemon if it is not running yet. Bound to Mod+Ctrl+S.
set -euo pipefail
CFG="quicksettings"

# daemon up -> just toggle
if qs -c "$CFG" ipc call quicksettings toggle 2>/dev/null; then
    exit 0
fi

# not running -> start detached daemon, wait for IPC, then open
qs -c "$CFG" -d >/dev/null 2>&1
for _ in $(seq 1 50); do
    if qs -c "$CFG" ipc call quicksettings open 2>/dev/null; then
        exit 0
    fi
    sleep 0.1
done
exit 1
