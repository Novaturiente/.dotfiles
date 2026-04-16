#!/usr/bin/env bash
# Execute password actions
set -euo pipefail

ACTION="$1"
ENTRY="$2"
CLIP_TIMEOUT=45
CLIP_SWITCH=10
TIMER_PID_FILE="/tmp/passrofi-timer.pid"

kill_timer() {
    if [[ -f "$TIMER_PID_FILE" ]]; then
        kill "$(<"$TIMER_PID_FILE")" 2>/dev/null || true
        rm -f "$TIMER_PID_FILE"
    fi
}

get_field() {
    local content
    content=$(pass show "$ENTRY" 2>/dev/null) || return 1
    case "$1" in
        password) echo "$content" | head -1 ;;
        username) echo "$content" | grep -i "^username:" | head -1 | sed 's/^[Uu]sername:[[:space:]]*//' ;;
        autotype)
            local seq
            seq=$(echo "$content" | grep -i "^autotype:" | head -1 | sed 's/^[Aa]utotype:[[:space:]]*//')
            echo "${seq:-username :tab password :enter}" ;;
    esac
}

case "$ACTION" in
    copy)
        kill_timer
        password=$(get_field password)
        username=$(get_field username)
        echo -n "$password" | wl-copy
        notify-send -a "PassRofi" -t 3000 " Password copied (username in ${CLIP_SWITCH}s)"
        (
            sleep "$CLIP_SWITCH"
            [[ -n "$username" ]] && echo -n "$username" | wl-copy && \
                notify-send -a "PassRofi" -t 3000 " Username copied (clearing in $((CLIP_TIMEOUT - CLIP_SWITCH))s)"
            sleep "$((CLIP_TIMEOUT - CLIP_SWITCH))"
            wl-copy --clear
            notify-send -a "PassRofi" -t 2000 " Clipboard cleared"
            rm -f "$TIMER_PID_FILE"
        ) &
        echo $! > "$TIMER_PID_FILE"
        ;;
    copy-user)
        kill_timer
        username=$(get_field username)
        echo -n "$username" | wl-copy
        notify-send -a "PassRofi" -t 3000 " Username copied"
        ( sleep "$CLIP_TIMEOUT"; wl-copy --clear ) &
        ;;
    copy-otp)
        kill_timer
        code=$(pass otp "$ENTRY" 2>/dev/null)
        remaining=$(( 30 - $(date +%s) % 30 ))
        echo -n "$code" | wl-copy
        notify-send -a "PassRofi" -t 3000 " TOTP copied: $code (expires in ${remaining}s)"
        ( sleep "$CLIP_TIMEOUT"; wl-copy --clear ) &
        ;;
    autotype)
        eww close passmanager
        sleep 0.15
        password=$(get_field password)
        username=$(get_field username)
        sequence=$(get_field autotype)
        read -ra tokens <<< "$sequence"
        i=0
        while [[ $i -lt ${#tokens[@]} ]]; do
            token="${tokens[$i]}"
            case "$token" in
                username)  wtype -- "$username" ;;
                password)  wtype -- "$password" ;;
                otp)       code=$(pass otp "$ENTRY" 2>/dev/null); wtype -- "$code" ;;
                :tab)      wtype -k Tab ;;
                :enter)    wtype -k Return ;;
                :delay)    i=$((i + 1)); sleep "${tokens[$i]:-1}" ;;
                *)         wtype -- "$token" ;;
            esac
            i=$((i + 1))
        done
        ;;
    edit)
        ghostty -e bash -c "pass edit '$ENTRY'"
        ;;
    delete)
        pass rm -f "$ENTRY"
        notify-send -a "PassRofi" -t 3000 " Deleted $ENTRY"
        ;;
esac
