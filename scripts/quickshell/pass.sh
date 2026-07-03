#!/usr/bin/env bash
# Toggle the Quickshell password manager. Captures the focused browser domain
# BEFORE our window steals focus, passes it as the search prefill, and starts
# the daemon if it isn't running yet. Bound to Mod+Shift+P.
set -euo pipefail
CFG="pass"
CTL="$HOME/.dotfiles/scripts/quickshell/passctl.sh"

domain=$(bash "$CTL" focused-domain 2>/dev/null || true)

# daemon up -> open with prefill
if qs -c "$CFG" ipc call pass open "$domain" 2>/dev/null; then
    exit 0
fi

# not running -> start detached daemon, wait for IPC, then open
qs -c "$CFG" -d >/dev/null 2>&1
for _ in $(seq 1 50); do
    if qs -c "$CFG" ipc call pass open "$domain" 2>/dev/null; then
        exit 0
    fi
    sleep 0.1
done
exit 1
