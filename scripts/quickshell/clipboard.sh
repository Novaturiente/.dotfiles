#!/usr/bin/env bash
# Toggle the Quickshell clipboard manager; start its daemon if not running. Mod+V.
set -euo pipefail
CFG="clipboard"
if qs -c "$CFG" ipc call clipboard toggle 2>/dev/null; then exit 0; fi
qs -c "$CFG" -d >/dev/null 2>&1
for _ in $(seq 1 50); do
    qs -c "$CFG" ipc call clipboard toggle 2>/dev/null && exit 0
    sleep 0.1
done
exit 1
