#!/usr/bin/env bash
# Compositor shim: same answers under niri and Hyprland, in niri's JSON shape.
#   wm.sh focused      -> {"app_id","title"} of the focused window
#   wm.sh windows      -> [{"id","app_id","title","pid","workspace_id","is_focused","focus_timestamp":{"secs"}}]
#   wm.sh focus <id>   -> focus that window
#   wm.sh dpms on|off  -> power monitors on/off
# Hyprland is detected by a live socket, not just the env var: a stale
# HYPRLAND_INSTANCE_SIGNATURE can linger in the systemd env after a session ends.
set -euo pipefail

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && hyprctl -j version >/dev/null 2>&1; then
    case "$1" in
        focused) hyprctl -j activewindow | jq -c '{app_id: .class, title}' ;;
        # focusHistoryID: 0 = most recent, so negate it to sort like niri's timestamp
        windows) hyprctl -j clients | jq -c '[.[] | select(.mapped) | {id: .address, app_id: .class, title, pid,
                     workspace_id: .workspace.id, is_focused: (.focusHistoryID == 0),
                     focus_timestamp: {secs: (0 - .focusHistoryID)}}]' ;;
        focus)   hyprctl dispatch "hl.dsp.focus({ window = 'address:$2' })" >/dev/null ;;
        dpms)    hyprctl dispatch "hl.dsp.dpms({ action = '$2' })" >/dev/null ;;
    esac
else
    case "$1" in
        focused) niri msg -j focused-window | jq -c '{app_id, title}' ;;
        windows) niri msg -j windows ;;
        focus)   niri msg action focus-window --id "$2" ;;
        dpms)    niri msg action "power-$2-monitors" ;;
    esac
fi
