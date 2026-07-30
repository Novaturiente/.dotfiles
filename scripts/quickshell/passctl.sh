#!/usr/bin/env bash
# passctl — headless backend for the Quickshell password manager.
# Backed by rbw (Bitwarden CLI, self-hosted vault). The rbw agent holds the
# unlocked vault and prompts via pinentry, so no session juggling here.
# The QML frontend only ever sees entry UUIDs; secrets stay in this script.
#
# Entry key = Bitwarden item UUID (rbw accepts it as a needle everywhere).
# Autotype sequences live in the item's notes as an "autotype: ..." line.
set -euo pipefail

CLIP_TIMEOUT=45
TIMER_PID_FILE="/tmp/passctl-timer.pid"
UNLOCK_LOCK="/tmp/passctl-unlock.lock"
DEFAULT_SEQ="username :tab password :enter"

notify() { notify-send -a "Pass" -t "${2:-3000}" "$1"; }

# Serialize the vault unlock across concurrent passctl processes. rbw-agent spawns
# a separate pinentry per locked client and never coalesces, so two rbw commands
# racing a locked vault = two PIN prompts + a TPM unseal race (which fails and
# falls back to the master password). flock funnels them: the first prompts once,
# the rest block, then find the vault already open. rbw unlock is a no-op when
# unlocked, so this is cheap on the warm path.
#
# 9>&- closes the lock fd for rbw: `rbw unlock` may fork a daemonized rbw-agent,
# which would inherit fd 9 and hold the flock for its whole life — every later
# unlock then blocks forever and Mod+Shift+P silently does nothing.
# -w 5 is the backstop: a leaked lock costs a 5s delay (and at worst a second PIN
# prompt), never a permanent hang.
ensure_unlocked() { ( flock -w 5 9 || true; rbw unlock 9>&- >/dev/null 2>&1 || true ) 9>"$UNLOCK_LOCK"; }

kill_timer() {
    if [[ -f "$TIMER_PID_FILE" ]]; then
        kill "$(<"$TIMER_PID_FILE")" 2>/dev/null || true
        rm -f "$TIMER_PID_FILE"
    fi
}

start_clear_timer() {
    ( sleep "$CLIP_TIMEOUT"
      wl-copy --clear
      notify-send -a "Pass" -t 2000 "Clipboard cleared"
      rm -f "$TIMER_PID_FILE"
    ) &
    echo $! >"$TIMER_PID_FILE"
}

# rbw add/edit read the new item from stdin when stdin is not a tty:
#   line 1 = password, remaining lines = notes. No editor, no secrets on disk.

item() { rbw get --raw "$1" 2>/dev/null; }   # full item JSON by uuid

# <uuid> <jq-filter> -> field value ('' when null)
field() { item "$1" | jq -r "$2 // empty"; }

# ── subcommands ─────────────────────────────────────────────────────────────
# entry = uuid; domain = the item's first URI host (so a browser-title prefill like
# "github.com" matches), falling back to the item name when it has no URI.
cmd_list() {   # JSON: [{entry,domain,user}]
    rbw list --fields id,name,user 2>/dev/null | while IFS=$'\t' read -r id name user; do
        local host
        host=$(item "$id" | jq -r '.data.uris[0].uri // empty' | sed -E 's|https?://||; s|www\.||; s|[/:?].*||')
        printf '%s\t%s\t%s\n' "$id" "${host:-$name}" "$user"
    done | jq -Rn '[inputs | split("\t") | {entry:.[0], domain:.[1], user:.[2]}]'
}

cmd_focused_domain() {
    local win app title
    win=$(niri msg focused-window 2>/dev/null) || return 0
    app=$(echo "$win" | grep "App ID:" | sed 's/.*App ID: "\(.*\)"/\1/')
    echo "$app" | grep -qiE 'zen|chrom|firefox|qutebrowser|thorium|brave|browser' || return 0
    title=$(echo "$win" | grep "Title:" | sed 's/.*Title: "\(.*\)"/\1/')
    echo "$title" | grep -oP '[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}(\.[a-zA-Z]{2,})?' | head -1
}

cmd_has_otp() { [[ -n "$(field "$1" '.data.totp')" ]] && echo yes || echo no; }

cmd_copy() {    # password + username -> clipboard, auto-clear
    local uuid="$1" json pw user
    json=$(item "$uuid")
    pw=$(jq -r '.data.password // empty' <<<"$json")
    user=$(jq -r '.data.username // empty' <<<"$json")
    [[ -z "$pw" ]] && { notify "No password for this entry"; return 1; }
    kill_timer
    printf '%s' "$pw" | wl-copy
    [[ -n "$user" ]] && printf '%s' "$user" | wl-copy
    notify "Password & username copied (clears in ${CLIP_TIMEOUT}s)"
    start_clear_timer
}

cmd_copy_field() {  # <uuid> <password|username>
    local uuid="$1" f="$2" val
    val=$(field "$uuid" ".data.$f")
    [[ -z "$val" ]] && { notify "No $f for this entry"; return 1; }
    kill_timer
    printf '%s' "$val" | wl-copy
    notify "${f^} copied (clears in ${CLIP_TIMEOUT}s)"
    start_clear_timer
}

cmd_totp() {
    local uuid="$1" code rem
    code=$(rbw code "$uuid" 2>/dev/null) || { notify "No TOTP for this entry"; return 1; }
    kill_timer
    rem=$((30 - $(date +%s) % 30))
    printf '%s' "$code" | wl-copy
    notify "TOTP copied: $code (expires ${rem}s)"
    start_clear_timer
}

cmd_autotype() {
    local uuid="$1" json pw user seq
    json=$(item "$uuid")
    pw=$(jq -r '.data.password // empty' <<<"$json")
    user=$(jq -r '.data.username // empty' <<<"$json")
    seq=$(cmd_get_autotype "$uuid")
    sleep 0.15                        # let focus return to the target window
    local IFS=' '; read -ra toks <<<"$seq"
    local i=0
    while [[ $i -lt ${#toks[@]} ]]; do
        case "${toks[$i]}" in
        username) wtype -- "$user" ;;
        password) wtype -- "$pw" ;;
        otp)      wtype -- "$(rbw code "$uuid" 2>/dev/null)" ;;
        :tab)     wtype -k Tab ;;
        :enter)   wtype -k Return ;;
        :delay)   i=$((i+1)); sleep "${toks[$i]:-1}" ;;
        *)        wtype -- "${toks[$i]}" ;;
        esac
        i=$((i+1))
    done
}

# autotype sequence lives in the notes as "autotype: <seq>"
cmd_get_autotype() {
    local seq
    seq=$(field "$1" '.notes' | grep -i '^autotype:' | head -1 | sed 's/^[Aa]utotype:[[:space:]]*//')
    echo "${seq:-$DEFAULT_SEQ}"
}

cmd_set_autotype() {   # <uuid> <seq>
    local uuid="$1" seq="$2" json pw notes
    json=$(item "$uuid")
    pw=$(jq -r '.data.password // empty' <<<"$json")
    notes=$(jq -r '.notes // empty' <<<"$json" | grep -iv '^autotype:' || true)
    { printf '%s\n' "$pw"
      [[ -n "$notes" ]] && printf '%s\n' "$notes"
      printf 'autotype: %s\n' "$seq"
    } | rbw edit "$uuid"
    notify "Autotype updated"
}

cmd_delete() { rbw remove "$1"; notify "Entry deleted"; }

cmd_edit() { setsid ghostty -e rbw edit "$1" >/dev/null 2>&1 & }

cmd_exists() {   # <name> <user>
    rbw list --fields name,user | grep -qxF "$1"$'\t'"$2" && echo yes || echo no
}

cmd_add() {     # <url> <username> <password|''>  ('' = generate); prints uuid
    local url="$1" user="$2" pw="${3:-}" name
    name=$(sed -E 's|https?://||; s|www\.||; s|/.*||' <<<"$url")
    if [[ -z "$pw" ]]; then
        pw=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 24)
        printf '%s' "$pw" | wl-copy
        notify "Password generated and copied" 5000
    fi
    if [[ "$(cmd_exists "$name" "$user")" == yes ]]; then
        printf '%s\n' "$pw" | rbw edit "$name" "$user"
    else
        printf '%s\n' "$pw" | rbw add --uri "$url" "$name" "$user"
    fi
    notify "Added $name ($user)"
    rbw list --fields id,name,user | awk -F'\t' -v n="$name" -v u="$user" '$2==n && $3==u {print $1; exit}'
}

cmd_sync() { rbw sync; }

cmd="${1:-}"; shift || true
# Every vault-touching command unlocks first, serialized, so concurrent invocations
# (e.g. list + sync on open) share a single pinentry prompt. focused-domain reads
# the window title only — no vault, no prompt.
case "$cmd" in
list|has-otp|copy|copy-field|totp|autotype|get-autotype|set-autotype|delete|edit|exists|add|sync|unlock) ensure_unlocked ;;
esac
case "$cmd" in
unlock)         : ;;   # ensure_unlocked already ran — prompt PIN before the UI opens
list)           cmd_list ;;
focused-domain) cmd_focused_domain ;;
has-otp)        cmd_has_otp "$@" ;;
copy)           cmd_copy "$@" ;;
copy-field)     cmd_copy_field "$@" ;;
totp)           cmd_totp "$@" ;;
autotype)       cmd_autotype "$@" ;;
get-autotype)   cmd_get_autotype "$@" ;;
set-autotype)   cmd_set_autotype "$@" ;;
delete)         cmd_delete "$@" ;;
edit)           cmd_edit "$@" ;;
exists)         cmd_exists "$@" ;;
add)            cmd_add "$@" ;;
sync)           cmd_sync ;;
*) echo "usage: passctl {list|focused-domain|has-otp|copy|copy-field|totp|autotype|get-autotype|set-autotype|delete|edit|exists|add|sync|unlock}" >&2; exit 2 ;;
esac
