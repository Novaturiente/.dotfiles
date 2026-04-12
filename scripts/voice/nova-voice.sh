#!/usr/bin/env bash
# nova-voice: Voice input daemon for Wayland/Niri
# Triggered by SIGUSR1 (Mod+V keybinding)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_FILE="$SCRIPT_DIR/commands.yaml"
VOSK_STREAM="$SCRIPT_DIR/vosk-stream.py"
PIDFILE="/tmp/nova-voice-stream.pid"
export YDOTOOL_SOCKET="/run/user/$(id -u)/.ydotool_socket"

# --- State ---
STATE="idle"  # idle | recording
VOSK_PID=""

# --- Filler words to strip from command phrases ---
FILLER_WORDS="that|this|it|the|a|please|now|ok|okay|then|so|just"

# --- Notification helper ---
notify() {
    local msg="$1"
    local urgency="${2:-low}"
    local timeout="${3:-2000}"
    notify-send -u "$urgency" -t "$timeout" \
        -h string:x-dunst-stack-tag:nova-voice \
        "Nova Voice" "$msg"
}

# --- Key name to ydotool keycode mapping ---
declare -A KEYCODES=(
    [ctrl]=29 [shift]=42 [alt]=56 [super]=125
    [return]=28 [tab]=15 [escape]=1 [backspace]=14
    [delete]=111 [home]=102 [end]=107 [space]=57
    [page_up]=104 [page_down]=109
    [a]=30 [b]=48 [c]=46 [d]=32 [e]=18 [f]=33 [g]=34
    [h]=35 [i]=23 [j]=36 [k]=37 [l]=38 [m]=50 [n]=49
    [o]=24 [p]=25 [q]=16 [r]=19 [s]=31 [t]=20 [u]=22
    [v]=47 [w]=17 [x]=45 [y]=21 [z]=44
    [0]=11 [1]=2 [2]=3 [3]=4 [4]=5 [5]=6 [6]=7 [7]=8 [8]=9 [9]=10
)

# --- Convert human-readable key combo to ydotool key sequence ---
# e.g., "ctrl+c" -> "29:1 46:1 46:0 29:0"
keys_to_ydotool() {
    local combo="$1"
    local press="" release=""

    IFS='+' read -ra parts <<< "$combo"
    for key in "${parts[@]}"; do
        local lkey="${key,,}"  # lowercase for lookup
        local code="${KEYCODES[$lkey]:-}"
        if [[ -z "$code" ]]; then
            echo "unknown key: $key" >&2
            return 1
        fi
        press+="${code}:1 "
        release="${code}:0 ${release}"
    done

    echo "${press}${release}"
}

# --- Parse commands.yaml into associative arrays ---
declare -A CMD_ACTIONS  # command_name -> action_type (key|spawn|niri)
declare -A CMD_VALUES   # command_name -> action_value
declare -a CMD_NAMES    # ordered list of command names

load_commands() {
    CMD_NAMES=()
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        # Parse "name: { type: value }"
        if [[ "$line" =~ ^([^:]+):[[:space:]]*\{[[:space:]]*(key|spawn|niri):[[:space:]]*\"([^\"]+)\" ]]; then
            local name="${BASH_REMATCH[1]}"
            local action_type="${BASH_REMATCH[2]}"
            local action_value="${BASH_REMATCH[3]}"
            name="$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            CMD_ACTIONS["$name"]="$action_type"
            CMD_VALUES["$name"]="$action_value"
            CMD_NAMES+=("$name")
        fi
    done < "$COMMANDS_FILE"
}

# --- Strip filler words from phrase ---
strip_fillers() {
    local phrase="$1"
    echo "$phrase" | sed -E "s/\b(${FILLER_WORDS})\b//gi" | sed 's/  */ /g;s/^ *//;s/ *$//'
}

# --- Levenshtein distance (pure bash, for short strings) ---
levenshtein() {
    local s="$1" t="$2"
    local s_len=${#s} t_len=${#t}
    local -a d

    for ((i = 0; i <= s_len; i++)); do d[$((i * (t_len + 1)))]=$i; done
    for ((j = 0; j <= t_len; j++)); do d[$j]=$j; done

    for ((i = 1; i <= s_len; i++)); do
        for ((j = 1; j <= t_len; j++)); do
            local cost=1
            [[ "${s:i-1:1}" == "${t:j-1:1}" ]] && cost=0
            local del=$((d[((i - 1) * (t_len + 1)) + j] + 1))
            local ins=$((d[(i * (t_len + 1)) + j - 1] + 1))
            local sub=$((d[((i - 1) * (t_len + 1)) + j - 1] + cost))
            local min=$del
            ((ins < min)) && min=$ins
            ((sub < min)) && min=$sub
            d[$((i * (t_len + 1) + j))]=$min
        done
    done
    echo "${d[$((s_len * (t_len + 1) + t_len))]}"
}

# --- Fuzzy match a phrase against commands ---
fuzzy_match() {
    local phrase="$1"
    local cleaned
    cleaned=$(strip_fillers "$phrase")
    cleaned="${cleaned,,}"

    # 1. Exact match
    for name in "${CMD_NAMES[@]}"; do
        [[ "${name,,}" == "$cleaned" ]] && echo "$name" && return
    done

    # 2. Substring match
    for name in "${CMD_NAMES[@]}"; do
        local lname="${name,,}"
        [[ "$cleaned" == *"$lname"* ]] && echo "$name" && return
        [[ "$lname" == *"$cleaned"* ]] && echo "$name" && return
    done

    # 3. Levenshtein distance <= 2
    local best_name="" best_dist=999
    for name in "${CMD_NAMES[@]}"; do
        local dist
        dist=$(levenshtein "$cleaned" "${name,,}")
        if ((dist < best_dist)); then
            best_dist=$dist
            best_name="$name"
        fi
    done
    if ((best_dist <= 2)); then
        echo "$best_name"
        return
    fi

    echo ""
}

# --- Execute a matched command ---
execute_command() {
    local name="$1"
    local action_type="${CMD_ACTIONS[$name]}"
    local action_value="${CMD_VALUES[$name]}"

    case "$action_type" in
        key)
            local ydotool_seq
            ydotool_seq=$(keys_to_ydotool "$action_value")
            if [[ -n "$ydotool_seq" ]]; then
                ydotool key $ydotool_seq
                notify "Voice: $name" low 1000
            fi
            ;;
        spawn)
            niri msg action spawn -- $action_value &
            notify "Voice: $name" low 1000
            ;;
        niri)
            niri msg action "$action_value"
            notify "Voice: $name" low 1000
            ;;
    esac
}

# --- Process a transcribed line ---
process_line() {
    local line="$1"
    [[ -z "$line" ]] && return

    if [[ "${line,,}" =~ ^command[[:space:]]+(.*) ]]; then
        local phrase="${BASH_REMATCH[1]}"
        local matched
        matched=$(fuzzy_match "$phrase")
        if [[ -n "$matched" ]]; then
            execute_command "$matched"
        else
            notify "Voice: unknown '$phrase'" normal 3000
        fi
    else
        ydotool type --key-delay 2 -- "$line"
    fi
}

# --- Start vosk and process output ---
start_recording() {
    [[ "$STATE" != "idle" ]] && return
    STATE="recording"
    notify "Voice input active" low 2000

    uv run "$VOSK_STREAM" 2>/dev/null | {
        while IFS= read -r line; do
            process_line "$line"
        done
    } &
    VOSK_PID=$!
    echo "$VOSK_PID" > "$PIDFILE"
}

# --- Stop recording ---
stop_recording() {
    [[ "$STATE" == "idle" ]] && return

    if [[ -n "$VOSK_PID" ]]; then
        # Kill the entire process group (uv + python + pipe)
        kill -- -"$VOSK_PID" 2>/dev/null || kill "$VOSK_PID" 2>/dev/null
        wait "$VOSK_PID" 2>/dev/null || true
    fi
    VOSK_PID=""
    rm -f "$PIDFILE"
    STATE="idle"
    notify "Voice input stopped" low 1000
}

# --- Signal handler ---
SIGNAL_RECEIVED=0
handle_signal() {
    SIGNAL_RECEIVED=1
}

# --- Cleanup on exit ---
cleanup() {
    stop_recording
    exit 0
}
trap cleanup EXIT SIGTERM SIGINT

# --- Main loop ---
main() {
    load_commands
    trap handle_signal USR1
    echo "nova-voice: daemon started (PID $$)"

    while true; do
        if [[ "$SIGNAL_RECEIVED" -eq 1 ]]; then
            SIGNAL_RECEIVED=0
            if [[ "$STATE" == "idle" ]]; then
                start_recording
            else
                stop_recording
            fi
        fi
        sleep 0.1
    done
}

main "$@"
