#!/usr/bin/env bash
# Toggle the Quickshell theme picker; start its daemon if not running. Mod+Shift+T.
set -euo pipefail
CFG="theme"
if qs -c "$CFG" ipc call theme toggle 2>/dev/null; then exit 0; fi
qs -c "$CFG" -d >/dev/null 2>&1
for _ in $(seq 1 50); do
    qs -c "$CFG" ipc call theme toggle 2>/dev/null && exit 0
    sleep 0.1
done
exit 1
