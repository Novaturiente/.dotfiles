#!/usr/bin/env bash
# Region screenshot to stdout (PNG). Captures the screen *before* slurp grabs
# keyboard focus, because losing focus makes apps close their open popups/menus.
# slurp returns logical coords, grim -o captures physical pixels: the crop is scaled by the output's scale.
set -euo pipefail
frame=$(mktemp --suffix=.png)
trap 'rm -f "$frame"' EXIT
# Focused output only: bare grim also grabs virtual outputs (e.g. W16) off to the side.
read -r out ox oy scale < <(~/.dotfiles/scripts/wm.sh output)
grim -o "$out" "$frame"
geom=$(slurp)                    # "x,y wxh"; non-zero exit on Esc aborts
crop=$(awk -v g="$geom" -v ox="$ox" -v oy="$oy" -v s="$scale" 'BEGIN {
    split(g, a, /[ ,x]/)          # x y w h
    printf "%dx%d+%d+%d", a[3]*s+0.5, a[4]*s+0.5, (a[1]-ox)*s+0.5, (a[2]-oy)*s+0.5 }')
magick "$frame" -crop "$crop" +repage png:-
