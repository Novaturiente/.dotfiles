#!/usr/bin/env bash
# Toggle the Quickshell keybindings cheat-sheet; start its daemon if not running.
# Bound to Mod+Shift+Slash.
set -euo pipefail
CFG="keybindings"
if qs -c "$CFG" ipc call kb toggle 2>/dev/null; then exit 0; fi
qs -c "$CFG" -d >/dev/null 2>&1
for _ in $(seq 1 50); do
    qs -c "$CFG" ipc call kb toggle 2>/dev/null && exit 0
    sleep 0.1
done
exit 1
