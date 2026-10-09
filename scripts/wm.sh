#!/usr/bin/env bash
# Compositor shim: same answers under niri and Hyprland, in niri's JSON shape.
#   wm.sh focused      -> {"app_id","title"} of the focused window
#   wm.sh windows      -> [{"id","app_id","title","pid","workspace_id","is_focused","focus_timestamp":{"secs"}}]
#   wm.sh focus <id>   -> focus that window
#   wm.sh dpms on|off  -> power monitors on/off
#   wm.sh name         -> "hyprland" or "niri"
#   wm.sh focus-app <name>...  -> focus the first window whose app_id (then
#                      title) contains a name, case-insensitive; exit 1 if none
# Hyprland is detected by a live socket, not just the env var: a stale
# HYPRLAND_INSTANCE_SIGNATURE can linger in the systemd env after a session ends.
set -euo pipefail

if [[ ${1:-} == focus-app ]]; then
    shift
    wins=$("$(readlink -f "$0")" windows)
    for name in "$@"; do
        [[ -n $name ]] || continue
        id=$(jq -r --arg n "${name,,}" '(map(select((.app_id // "") | ascii_downcase | contains($n)))
            + map(select((.title // "") | ascii_downcase | contains($n)))) | .[0].id // empty' <<<"$wins")
        [[ -n $id ]] && exec "$(readlink -f "$0")" focus "$id"
    done
    exit 1
fi

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && hyprctl -j version >/dev/null 2>&1; then
    case "$1" in
        focused) hyprctl -j activewindow | jq -c '{app_id: .class, title}' ;;
        # focusHistoryID: 0 = most recent, so negate it to sort like niri's timestamp
        windows) hyprctl -j clients | jq -c '[.[] | select(.mapped) | {id: .address, app_id: .class, title, pid,
                     workspace_id: .workspace.id, is_focused: (.focusHistoryID == 0),
                     focus_timestamp: {secs: (0 - .focusHistoryID)}}]' ;;
        focus)   hyprctl dispatch "hl.dsp.focus({ window = 'address:$2' })" >/dev/null ;;
        dpms)    hyprctl dispatch "hl.dsp.dpms({ action = '$2' })" >/dev/null ;;
        name)    echo hyprland ;;
    esac
else
    case "$1" in
        focused) niri msg -j focused-window | jq -c '{app_id, title}' ;;
        windows) niri msg -j windows ;;
        focus)   niri msg action focus-window --id "$2" ;;
        dpms)    niri msg action "power-$2-monitors" ;;
        name)    echo niri ;;
    esac
fi
