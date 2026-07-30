#!/usr/bin/env bash
# Toggle the Zen URL bar (quickshell). If its daemon isn't running yet,
# start it, then show the window. Makes Mod+S work even before login autostart.
set -euo pipefail
CFG="zen-url"

# daemon already up -> just toggle
if qs -c "$CFG" ipc call menu toggle 2>/dev/null; then
    exit 0
fi

# not running -> start detached daemon, wait for its IPC, then show
qs -c "$CFG" -d >/dev/null 2>&1
for _ in $(seq 1 50); do          # up to ~5s, exits as soon as IPC answers
    if qs -c "$CFG" ipc call menu toggle 2>/dev/null; then
        exit 0
    fi
    sleep 0.1
done
exit 1
