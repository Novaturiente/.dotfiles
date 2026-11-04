#!/usr/bin/env bash
# Mod+Shift+S: freeze the screen, crop it in satty (full screen, so open popups
# stay visible), then reopen only the cropped part in satty for text/arrows/copy.
set -euo pipefail
crop=$(mktemp --suffix=.png)
trap 'rm -f "$crop"' EXIT
# Enter saves the crop and closes; Esc exits without a file. Copy here (no
# crop) goes through wl-copy: satty's own clipboard dies with --early-exit.
# Focused output only: bare grim also grabs virtual outputs (e.g. W16) off to the side.
out=$(hyprctl -j monitors | jq -r '.[] | select(.focused).name')
grim -o "$out" - | satty -f - --fullscreen --initial-tool crop -o "$crop" \
    --actions-on-enter save-to-file,exit --early-exit --disable-notifications \
    --copy-command wl-copy
[ -s "$crop" ] || exit 0
satty -f "$crop" --copy-command wl-copy
