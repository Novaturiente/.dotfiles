#!/usr/bin/env bash
# Toggle the Quickshell window switcher; start its daemon if not running. Mod+Tab.
set -euo pipefail
CFG="switcher"
if qs -c "$CFG" ipc call switcher toggle 2>/dev/null; then exit 0; fi
qs -c "$CFG" -d >/dev/null 2>&1
for _ in $(seq 1 50); do
    qs -c "$CFG" ipc call switcher toggle 2>/dev/null && exit 0
    sleep 0.1
done
exit 1
