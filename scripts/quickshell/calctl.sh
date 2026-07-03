#!/usr/bin/env bash
# calctl — headless backend for the Quickshell calendar. Wraps khal.
# The QML frontend renders lists/forms and dispatches these subcommands; all
# khal/ikhal/ics work lives here. Adapted from scripts/rofi/calendar.sh.
set -euo pipefail

KHAL_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/khal/calendars"
RANGE_DAYS=60
TERMINAL="${TERMINAL:-ghostty}"
export GDK_BACKEND=wayland

notify() { command -v notify-send >/dev/null && notify-send "Calendar" "$1"; }

event_file() { find "$KHAL_BASE" -type f -name "${1}.ics" 2>/dev/null | head -n1; }

cmd_list() {   # JSON [{uid, when, title}] over the next RANGE_DAYS
    khal list now "${RANGE_DAYS}d" --day-format "" --once \
        --format "{uid}	{start-date} {start-time}	{title}" 2>/dev/null \
        | grep -vE '^[[:space:]]*$' \
        | jq -Rn '[inputs | split("\t") | {uid:.[0], when:(.[1]|gsub("^ +| +$";"")), title:.[2]}]'
}

cmd_details() {  # <uid> -> JSON {title,time,loc,desc}
    local uid="$1" f
    f() { khal list now "${RANGE_DAYS}d" --format "{uid}	$1" 2>/dev/null | grep -F "$uid	" | head -1 | cut -f2-; }
    jq -n --arg title "$(f '{title}')" --arg time "$(f '{start} - {end}')" \
          --arg loc "$(f '{location}')" --arg desc "$(f '{description}')" \
          '{title:$title, time:$time, loc:$loc, desc:$desc}'
}

cmd_add() {   # <date_iso> <start> <end> <title> <details>   (start/end may be "")
    local date_iso="$1" start="$2" end="$3" title="$4" details="${5:-}"
    [[ -z "$title" ]] && { notify "Aborted: title required"; echo "ERR:title"; return; }
    local date_khal
    date_khal=$(date -d "$date_iso" +%d/%m/%Y 2>/dev/null) || { notify "Bad date"; echo "ERR:date"; return; }

    # normalise times to khal's %I:%M %p combined-token format
    local sdt="" edt=""
    if [[ -n "$start" ]]; then
        local sn; sn=$(date -d "$start" +"%I:%M %p" 2>/dev/null) || sn="$start"; [[ -z "$sn" ]] && sn="$start"
        sdt="$date_khal $sn"
    fi
    if [[ -n "$start" && -n "$end" ]]; then
        local en; en=$(date -d "$end" +"%I:%M %p" 2>/dev/null) || en="$end"; [[ -z "$en" ]] && en="$end"
        edt="$date_khal $en"
    fi

    local args=(new)
    if [[ -n "$sdt" ]]; then args+=("$sdt"); [[ -n "$edt" ]] && args+=("$edt"); else args+=("$date_khal"); fi
    args+=("$title")
    [[ -n "$details" ]] && args+=(:: "$details")

    if khal "${args[@]}" >/dev/null 2>&1; then notify "Added: $title"; echo "OK"; else notify "Failed to add event"; echo "ERR:khal"; fi
}

cmd_delete() {
    local f; f=$(event_file "$1")
    [[ -n "$f" ]] && { /usr/bin/rm -f "$f" && notify "Deleted"; echo "OK"; } || { notify "Event not found"; echo "ERR:notfound"; }
}

cmd_copy() {   # <uid> : copy full details to clipboard
    local d; d=$(cmd_details "$1")
    printf '%s\nWhen: %s\nWhere: %s\n\n%s\n' \
        "$(jq -r .title <<<"$d")" "$(jq -r .time <<<"$d")" "$(jq -r .loc <<<"$d")" "$(jq -r .desc <<<"$d")" \
        | wl-copy
    notify "Details copied"
}

cmd_edit()   { setsid "$TERMINAL" -e ikhal >/dev/null 2>&1 & }

cmd="${1:-}"; shift || true
case "$cmd" in
list)    cmd_list ;;
details) cmd_details "$@" ;;
add)     cmd_add "$@" ;;
delete)  cmd_delete "$@" ;;
copy)    cmd_copy "$@" ;;
edit)    cmd_edit ;;
*) echo "usage: calctl {list|details|add|delete|copy|edit}" >&2; exit 2 ;;
esac
