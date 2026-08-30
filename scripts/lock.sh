#!/usr/bin/env bash
# Lock with swaylock-effects, using the CURRENT wallpaper as the background.
# swaylock's own `screenshots` option would show whatever is on screen, i.e.
# your open windows; DMS rotates the wallpaper, so ask it rather than hardcode.
# ponytail: falls back to a flat Catppuccin base if dms is not answering.

wallpaper=$(dms ipc call wallpaper get 2>/dev/null)

if [ -f "$wallpaper" ]; then
    exec swaylock -i "$wallpaper"
else
    exec swaylock -c 1e1e2e
fi
