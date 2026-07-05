#!/usr/bin/env bash
# kbctl — headless backend for the Quickshell keybindings cheat-sheet.
# `refresh` re-runs the per-app extractors (with the CORRECT config paths, incl.
# niri's binds now living in modules/binds.kdl); `list` emits every app's
# bindings as JSON for the tabbed UI. Source of truth: scripts/keybindings/bindings/*.txt
set -euo pipefail

KB="$HOME/.dotfiles/scripts/keybindings"
BIN="$KB/bindings"

cmd_refresh() {
    bash "$KB/extract-niri-keybindings.sh"       "$HOME/.config/niri/modules/binds.kdl"        >/dev/null 2>&1 || true
    bash "$KB/extract-neovim-keybindings.sh"                                                     >/dev/null 2>&1 || true
    bash "$KB/extract-qutebrowser-keybindings.sh" "$HOME/.config/qutebrowser_work/config/config.py" >/dev/null 2>&1 || true
}

# JSON: [{app, count, bindings:[{key,desc}]}]  (skips *-default.txt merge bases)
cmd_list() {
    local first=1
    printf '['
    for f in "$BIN"/*.txt; do
        [[ -f "$f" ]] || continue
        local name; name=$(basename "$f" .txt)
        [[ "$name" == *-default ]] && continue
        [[ $first -eq 1 ]] || printf ','
        first=0
        # split each line into key + desc on the first run of 2+ spaces
        awk '
            { line=$0; sub(/[[:space:]]+$/,"",line) }
            line=="" { next }
            {
              if (match(line, /  +/)) {
                key=substr(line,1,RSTART-1); desc=substr(line,RSTART+RLENGTH)
              } else { key=line; desc="" }
              print key "\t" desc
            }' "$f" \
        | jq -Rn --arg app "$name" \
            '{app:$app, bindings:[inputs|split("\t")|{key:.[0], desc:(.[1]//"")}]} | .count=(.bindings|length)'
    done
    printf ']'
}

case "${1:-}" in
refresh) cmd_refresh ;;
list)    cmd_list ;;
*) echo "usage: kbctl {refresh|list}" >&2; exit 2 ;;
esac
