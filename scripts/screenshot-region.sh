#!/usr/bin/env bash
# Region screenshot to stdout (PNG). Captures the screen *before* slurp grabs
# keyboard focus, because losing focus makes apps close their open popups/menus.
# shortcut: assumes all outputs at scale 1 (slurp logical coords == grim pixels); fix the crop math if a scaled monitor is added.
set -euo pipefail
frame=$(mktemp --suffix=.png)
trap 'rm -f "$frame"' EXIT
# Focused output only: bare grim also grabs virtual outputs (e.g. W16) off to the side.
read -r out ox oy < <(hyprctl -j monitors | jq -r '.[] | select(.focused) | "\(.name) \(.x) \(.y)"')
grim -o "$out" "$frame"
geom=$(slurp)                    # "x,y wxh"; non-zero exit on Esc aborts
read -r xy wh <<<"$geom"
magick "$frame" -crop "${wh}+$(( ${xy%,*} - ox ))+$(( ${xy#*,} - oy ))" +repage png:-
