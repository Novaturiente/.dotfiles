#!/usr/bin/env bash
# passctl — headless backend for the Quickshell pass manager.
# All pass/gpg/clipboard/wtype/otp work lives here; the QML frontend only shows
# entry NAMES and dispatches these subcommands. Secrets never touch the UI.
# Adapted from scripts/rofi/passrofi.sh (same behaviour, no rofi prompts).
set -euo pipefail

# Spawned from niri (non-login shell) — set gnupg home explicitly or gpg falls
# back to ~/.gnupg and can't find the key.
export GNUPGHOME="${GNUPGHOME:-${XDG_DATA_HOME:-$HOME/.local/share}/gnupg}"

STORE_DIR="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
WEB_DIR="$STORE_DIR/web"
CLIP_TIMEOUT=45
TIMER_PID_FILE="/tmp/passrofi-timer.pid"

notify() { notify-send -a "Pass" -t "${2:-3000}" "$1"; }

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

get_field() {
    local entry="$1" field="$2" content
    content=$(pass show "$entry" 2>/dev/null) || return 1
    case "$field" in
    password) echo "$content" | head -1 ;;
    username) echo "$content" | grep -i "^username:" | head -1 | sed 's/^[Uu]sername:[[:space:]]*//' ;;
    url)      echo "$content" | grep -i "^url:" | head -1 | sed 's/^[Uu]rl:[[:space:]]*//' ;;
    autotype)
        local seq
        seq=$(echo "$content" | grep -i "^autotype:" | head -1 | sed 's/^[Aa]utotype:[[:space:]]*//')
        echo "${seq:-username :tab password :enter}" ;;
    has_otp) echo "$content" | grep -q "^otpauth://" && echo "yes" || echo "no" ;;
    esac
}

# ── subcommands ─────────────────────────────────────────────────────────────
cmd_list() {   # JSON: [{entry,domain,user}]
    [[ -d "$WEB_DIR" ]] || { echo "[]"; return; }
    find "$WEB_DIR" -name "*.gpg" -type f | sort | while read -r f; do
        local rel="${f#"$WEB_DIR"/}"; rel="${rel%.gpg}"
        printf '%s\t%s\t%s\n' "web/$rel" "${rel%%/*}" "${rel#*/}"
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

cmd_has_otp() { get_field "$1" has_otp; }

cmd_copy() {    # password + username -> clipboard, auto-clear
    local entry="$1" pw user
    pw=$(get_field "$entry" password)
    user=$(get_field "$entry" username)
    [[ -z "$pw" ]] && { notify "No password for $entry"; return 1; }
    kill_timer
    printf '%s' "$pw" | wl-copy
    [[ -n "$user" ]] && printf '%s' "$user" | wl-copy
    notify "Password & username copied (clears in ${CLIP_TIMEOUT}s)"
    start_clear_timer
}

cmd_copy_field() {  # <entry> <password|username>
    local entry="$1" field="$2" val
    val=$(get_field "$entry" "$field")
    [[ -z "$val" ]] && { notify "No $field for $entry"; return 1; }
    kill_timer
    printf '%s' "$val" | wl-copy
    notify "${field^} copied (clears in ${CLIP_TIMEOUT}s)"
    start_clear_timer
}

cmd_totp() {
    local entry="$1" code rem
    [[ "$(get_field "$entry" has_otp)" == "yes" ]] || { notify "No TOTP for this entry"; return 1; }
    kill_timer
    code=$(pass otp "$entry" 2>/dev/null)
    rem=$((30 - $(date +%s) % 30))
    printf '%s' "$code" | wl-copy
    notify "TOTP copied: $code (expires ${rem}s)"
    start_clear_timer
}

cmd_autotype() {
    local entry="$1" pw user seq
    pw=$(get_field "$entry" password)
    user=$(get_field "$entry" username)
    seq=$(get_field "$entry" autotype)
    sleep 0.15                        # let focus return to the target window
    local IFS=' '; read -ra toks <<<"$seq"
    local i=0
    while [[ $i -lt ${#toks[@]} ]]; do
        case "${toks[$i]}" in
        username) wtype -- "$user" ;;
        password) wtype -- "$pw" ;;
        otp)      wtype -- "$(pass otp "$entry" 2>/dev/null)" ;;
        :tab)     wtype -k Tab ;;
        :enter)   wtype -k Return ;;
        :delay)   i=$((i+1)); sleep "${toks[$i]:-1}" ;;
        *)        wtype -- "${toks[$i]}" ;;
        esac
        i=$((i+1))
    done
}

cmd_get_autotype() { get_field "$1" autotype; }

cmd_set_autotype() {
    local entry="$1" seq="$2" content new
    content=$(pass show "$entry" 2>/dev/null)
    new=$(echo "$content" | grep -iv "^autotype:")
    new="$new
autotype: $seq"
    echo "$new" | pass insert -m -f "$entry"
    notify "Autotype updated"
}

cmd_remove_totp() {
    local entry="$1" content new
    content=$(pass show "$entry" 2>/dev/null)
    new=$(echo "$content" | grep -v "^otpauth://")
    echo "$new" | pass insert -m -f "$entry"
    notify "TOTP removed from $entry"
}

cmd_delete() { pass rm -f "$1"; notify "Deleted $1"; }

cmd_edit() { setsid ghostty -e bash -c "pass edit '$1'" >/dev/null 2>&1 & }

cmd_exists() { pass show "$1" &>/dev/null && echo yes || echo no; }

cmd_add() {     # <url> <username> <password|''>  ('' = generate); prints entry
    local url="$1" user="$2" pw="${3:-}" domain entry
    domain=$(echo "$url" | sed -E 's|https?://||; s|www\.||; s|/.*||')
    entry="web/$domain/$user"
    if [[ -z "$pw" ]]; then
        pw=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 24)
        printf '%s' "$pw" | wl-copy
        notify "Password generated and copied" 5000
    fi
    printf '%s\nurl: %s\nusername: %s\n' "$pw" "$url" "$user" | pass insert -m -f "$entry"
    notify "Added $entry"
    echo "$entry"
}

cmd_scan_qr() {     # prints otpauth:// uri or ERR:
    local geo uri
    geo=$(slurp 2>/dev/null) || { echo "ERR:cancelled"; return; }
    grim -g "$geo" /tmp/passctl-qr.png
    uri=$(zbarimg --raw -q /tmp/passctl-qr.png 2>/dev/null) || { rm -f /tmp/passctl-qr.png; echo "ERR:no-qr"; return; }
    rm -f /tmp/passctl-qr.png
    [[ "$uri" == otpauth://* ]] && echo "$uri" || echo "ERR:not-otpauth"
}

cmd_import_file() {  # <path> -> otpauth uris, one per line
    local file="$1" ext="${1##*.}"
    case "$ext" in
    png|jpg|jpeg|svg) zbarimg --raw -q "$file" 2>/dev/null | grep '^otpauth://' || true ;;
    txt)              grep '^otpauth://' "$file" 2>/dev/null || true ;;
    json)
        python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); out=[]
if 'entries' in d:
    for e in d['entries']:
        u=e.get('content',{}).get('uri') or e.get('info',{}).get('uri') or e.get('uri','')
        if u.startswith('otpauth://'): out.append(u)
elif 'services' in d:
    for s in d['services']:
        u=s.get('otp',{}).get('link','') or s.get('secret','')
        if u.startswith('otpauth://'): out.append(u)
elif isinstance(d,list):
    for e in d:
        u=e.get('uri','')
        if u.startswith('otpauth://'): out.append(u)
print('\n'.join(out))
" "$file" 2>/dev/null || true ;;
    esac
}

cmd_attach_totp() {  # <uri> <target>   target = existing 'web/..' OR '--new <issuer> <account>'
    local uri="$1" target="$2" entry
    [[ "$uri" == otpauth://* ]] || { notify "Invalid URI"; return 1; }
    if [[ "$target" == "--new" ]]; then
        local issuer="$3" account="$4" domain
        domain=$(echo "${issuer,,}" | sed 's/ /-/g')
        entry="web/$domain/$account"
        printf 'CHANGE_ME\nurl: https://%s\nusername: %s\n' "$domain" "$account" | pass insert -m -f "$entry"
    else
        entry="$target"
    fi
    echo "$uri" | pass otp append -s "$entry" 2>/dev/null \
        || echo "$uri" | pass otp insert -s -f "$entry" 2>/dev/null \
        || { notify "Failed to add TOTP to $entry"; return 1; }
    local code; code=$(pass otp "$entry" 2>/dev/null) || { notify "TOTP added, verify failed"; return 1; }
    notify "TOTP added to $entry (code: $code)" 5000
}

# parse otpauth uri -> "issuer\taccount" (for the attach picker)
cmd_parse_uri() {
    local uri="$1" label issuer account
    label=$(echo "$uri" | sed -E 's|otpauth://[a-z]+/||; s|\?.*||')
    if [[ "$label" == *:* ]]; then issuer="${label%%:*}"; account="${label#*:}"; else issuer="$label"; account="$label"; fi
    issuer=$(printf '%b' "${issuer//%/\\x}"); account=$(printf '%b' "${account//%/\\x}")
    printf '%s\t%s\n' "$issuer" "$account"
}

cmd="${1:-}"; shift || true
case "$cmd" in
list)          cmd_list ;;
focused-domain) cmd_focused_domain ;;
has-otp)       cmd_has_otp "$@" ;;
copy)          cmd_copy "$@" ;;
copy-field)    cmd_copy_field "$@" ;;
totp)          cmd_totp "$@" ;;
autotype)      cmd_autotype "$@" ;;
get-autotype)  cmd_get_autotype "$@" ;;
set-autotype)  cmd_set_autotype "$@" ;;
remove-totp)   cmd_remove_totp "$@" ;;
delete)        cmd_delete "$@" ;;
edit)          cmd_edit "$@" ;;
exists)        cmd_exists "$@" ;;
add)           cmd_add "$@" ;;
scan-qr)       cmd_scan_qr ;;
import-file)   cmd_import_file "$@" ;;
attach-totp)   cmd_attach_totp "$@" ;;
parse-uri)     cmd_parse_uri "$@" ;;
*) echo "usage: passctl {list|focused-domain|has-otp|copy|copy-field|totp|autotype|get-autotype|set-autotype|remove-totp|delete|edit|exists|add|scan-qr|import-file|attach-totp|parse-uri}" >&2; exit 2 ;;
esac
