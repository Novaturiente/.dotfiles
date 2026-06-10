#!/usr/bin/env bash
#
# calendar.sh - rofi/zenity front-end for khal
#
#   Add events     : zenity form (clickable date picker + time/title/url/details)
#   View upcoming  : rofi list -> per-event actions
#   Copy details   : full text or just the URLs -> wl-clipboard
#   Edit           : hands off to ikhal (khal has no CLI editor)
#   Delete         : removes the event's .ics file (filename == uid)
#
# Deps: khal, ikhal, zenity, rofi, wl-copy, a terminal (ghostty)

export GDK_BACKEND=wayland

KHAL_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/khal/calendars"
RANGE_DAYS=60                       # how far ahead "upcoming" looks
TERMINAL="${TERMINAL:-ghostty}"     # terminal used to launch ikhal
SEP=$'\x1f'                         # unit separator, won't collide with text

notify() { command -v notify-send >/dev/null && notify-send "Calendar" "$1"; }

# --- find the .ics file for a uid across every configured calendar ----------
event_file() {
    local uid="$1"
    find "$KHAL_BASE" -type f -name "${uid}.ics" 2>/dev/null | head -n1
}

# ---------------------------------------------------------------------------
# Add a new event via a single zenity form
# ---------------------------------------------------------------------------
add_event() {
    local date_iso out start end title details

    # zenity --forms cannot host a calendar with a fixed output format
    # (--date-format is rejected there), so pick the date in its own dialog
    # where --date-format works and gives an unambiguous ISO date.
    date_iso=$(zenity --calendar --title="Event date" --text="Pick the date" \
        --date-format="%Y-%m-%d") || return            # cancelled

    # zenity has no native clock widget; use dropdown time pickers instead -
    # one combo each for start/end, 15-minute steps, 12h labels. "(none)" on
    # start = all-day event; "(none)" on end = khal's default duration.
    local times="(none)" h m
    for h in $(seq 0 23); do for m in 00 15 30 45; do
        times+="|$(date -d "$h:$m" +'%I:%M %p')"
    done; done

    out=$(zenity --forms --title="New Event" --text="Details for $date_iso" \
        --separator="$SEP" \
        --add-combo="Start time" --combo-values="$times" \
        --add-combo="End time"   --combo-values="$times" \
        --add-entry="Title" \
        --add-entry="Details") || return                # cancelled

    IFS="$SEP" read -r start end title details <<<"$out"

    # treat the "(none)" sentinel as empty
    [[ "$start" == "(none)" ]] && start=""
    [[ "$end"   == "(none)" ]] && end=""

    [[ -z "$title" ]] && { notify "Aborted: title required"; return; }

    # zenity gives ISO (YYYY-MM-DD); khal wants its locale format (%d/%m/%Y)
    local date_khal
    date_khal=$(date -d "$date_iso" +%d/%m/%Y 2>/dev/null) || {
        notify "Aborted: bad date '$date_iso'"; return; }

    # khal's positional time parser is unreliable with this 12h locale unless
    # each datetime is one combined token in datetimeformat (%d/%m/%Y %I:%M %p).
    # Normalise whatever the user typed ("14:30", "2:30pm", ...) to %I:%M %p.
    local sdt="" edt=""
    if [[ -n "$start" ]]; then
        local sn; sn=$(date -d "$start" +"%I:%M %p" 2>/dev/null) || sn="$start"
        [[ -z "$sn" ]] && sn="$start"
        sdt="$date_khal $sn"
    fi
    if [[ -n "$start" && -n "$end" ]]; then
        local en; en=$(date -d "$end" +"%I:%M %p" 2>/dev/null) || en="$end"
        [[ -z "$en" ]] && en="$end"
        edt="$date_khal $en"
    fi

    # build args: START [END] SUMMARY  [:: DESCRIPTION]
    # START is a combined datetime token, or the bare date for an all-day event.
    local args=(new)
    if [[ -n "$sdt" ]]; then
        args+=("$sdt")
        [[ -n "$edt" ]] && args+=("$edt")
    else
        args+=("$date_khal")
    fi
    args+=("$title")
    [[ -n "$details" ]] && args+=(:: "$details")

    if khal "${args[@]}" >/dev/null 2>&1; then
        notify "Added: $title"
    else
        notify "Failed to add event (check times)"
    fi
}

# ---------------------------------------------------------------------------
# Pick an upcoming event -> returns its uid on stdout
# ---------------------------------------------------------------------------
pick_event() {
    local list
    list=$(khal list now "${RANGE_DAYS}d" --day-format "" --once \
        --format "{uid}	{start-date} {start-time} {title}" 2>/dev/null \
        | grep -vE '^\s*$')
    [[ -z "$list" ]] && { notify "No events in next ${RANGE_DAYS} days"; return 1; }

    # column 1 (uid) hidden, full line returned on select
    local sel
    sel=$(printf '%s\n' "$list" \
        | rofi -dmenu -i -p "󰃭 EVENTS" -theme black -display-columns 2) || return 1
    [[ -z "$sel" ]] && return 1
    printf '%s' "${sel%%	*}"   # text before first tab = uid
}

# ---------------------------------------------------------------------------
# Action menu for a chosen event
# ---------------------------------------------------------------------------
event_actions() {
    local uid="$1"
    local title time loc desc
    title=$(khal list now "${RANGE_DAYS}d" --format "{uid}	{title}"      2>/dev/null | grep -F "$uid	" | head -1 | cut -f2-)
    time=$( khal list now "${RANGE_DAYS}d" --format "{uid}	{start} - {end}" 2>/dev/null | grep -F "$uid	" | head -1 | cut -f2-)
    loc=$(  khal list now "${RANGE_DAYS}d" --format "{uid}	{location}"   2>/dev/null | grep -F "$uid	" | head -1 | cut -f2-)
    desc=$( khal list now "${RANGE_DAYS}d" --format "{uid}	{description}" 2>/dev/null | grep -F "$uid	" | head -1 | cut -f2-)

    local action
    action=$(printf '%s\n' \
        "󰋽  View details" \
        "󰏫  Edit (ikhal)" \
        "󰆴  Delete" \
        | rofi -dmenu -i -p "󰃭 $title" -theme black) || return

    case "$action" in
    *"View details"*)
        # dump details to a throwaway file and open it in a temporary nvim
        # window; yank whatever you need (links, etc), file is removed on quit.
        local tmp
        tmp=$(mktemp --suffix=.md /tmp/khal-event-XXXXXX) || { notify "mktemp failed"; return; }
        printf '# %s\n\nWhen : %s\nWhere: %s\n\n%s\n' \
            "$title" "$time" "$loc" "$desc" >"$tmp"
        setsid "$TERMINAL" -e sh -c "nvim '$tmp'; rm -f '$tmp'" >/dev/null 2>&1 &
        ;;
    *"Edit"*)
        setsid "$TERMINAL" -e ikhal >/dev/null 2>&1 &
        ;;
    *"Delete"*)
        local confirm
        confirm=$(printf ' Yes\n No' | rofi -dmenu -i -p "󰆴 Delete: $title ?" -theme power) || return
        [[ "$confirm" == *Yes* ]] || return
        local f; f=$(event_file "$uid")
        if [[ -n "$f" ]]; then
            /usr/bin/rm -f "$f" && notify "Deleted: $title" || notify "Delete failed"
        else
            notify "Event file not found"
        fi
        ;;
    esac
}

# ---------------------------------------------------------------------------
# Main menu
# ---------------------------------------------------------------------------
main_menu() {
    local choice
    choice=$(printf '%s\n' \
        "󰃷  Add event" \
        "󰃭  Upcoming events" \
        "󰸗  Open ikhal" \
        | rofi -dmenu -i -p "󰸗 CALENDAR" -theme black) || exit 0

    case "$choice" in
    *"Add event"*)       add_event ;;
    *"Upcoming events"*) uid=$(pick_event) && [[ -n "$uid" ]] && event_actions "$uid" ;;
    *"Open ikhal"*)      setsid "$TERMINAL" -e ikhal >/dev/null 2>&1 & ;;
    esac
}

case "${1:-}" in
add)  add_event ;;
list) uid=$(pick_event) && [[ -n "$uid" ]] && event_actions "$uid" ;;
*)    main_menu ;;
esac
