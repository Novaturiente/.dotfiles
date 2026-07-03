#!/usr/bin/env bash
# Toggle the Quickshell app launcher; start its daemon if not running. Mod+D.
set -euo pipefail
CFG="launcher"
if qs -c "$CFG" ipc call launcher toggle 2>/dev/null; then exit 0; fi
qs -c "$CFG" -d >/dev/null 2>&1
for _ in $(seq 1 50); do
    qs -c "$CFG" ipc call launcher toggle 2>/dev/null && exit 0
    sleep 0.1
done
exit 1
