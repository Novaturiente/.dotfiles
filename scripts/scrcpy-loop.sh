#!/usr/bin/env bash
# Run scrcpy headless; reconnect 2s after it exits (device disconnect/loss).
while true; do
    scrcpy --no-window --keep-active "$@"
    sleep 2
done
