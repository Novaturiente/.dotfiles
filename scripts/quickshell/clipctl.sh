#!/usr/bin/env bash
# clipctl — headless backend for the Quickshell clipboard manager (cliphist).
#   list        -> JSON [{id,image,text,thumb}] (newest first, images decoded to cache)
#   copy <id>   -> put that entry back on the clipboard
#   delete <id> -> remove that entry from history
#   wipe        -> clear all history
set -euo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-clip"
MAX=300
mkdir -p "$CACHE"

is_image_re='^\[\[ binary data .*(png|jpe?g|gif|bmp|webp)'

cmd_list() {
    cliphist list 2>/dev/null | head -n "$MAX" | while IFS=$'\t' read -r id preview; do
        [[ -z "$id" ]] && continue
        if [[ "$preview" =~ $is_image_re ]]; then
            thumb="$CACHE/$id.png"
            [[ -f "$thumb" ]] || cliphist decode "$id" >"$thumb" 2>/dev/null || true
            printf '%s\t1\t%s\t%s\n' "$id" "$preview" "$thumb"
        else
            printf '%s\t0\t%s\t\n' "$id" "$preview"
        fi
    done | jq -Rn '[inputs | split("\t") | {id:.[0], image:(.[1]=="1"), text:.[2], thumb:.[3]}]'
}

cmd_copy()   { cliphist decode "$1" | wl-copy; }
cmd_delete() { cliphist list 2>/dev/null | awk -F'\t' -v i="$1" '$1==i' | cliphist delete; rm -f "$CACHE/$1.png"; }
cmd_wipe()   { cliphist wipe; rm -f "$CACHE"/*.png 2>/dev/null || true; }

case "${1:-}" in
list)   cmd_list ;;
copy)   cmd_copy "$2" ;;
delete) cmd_delete "$2" ;;
wipe)   cmd_wipe ;;
*) echo "usage: clipctl {list|copy <id>|delete <id>|wipe}" >&2; exit 2 ;;
esac
