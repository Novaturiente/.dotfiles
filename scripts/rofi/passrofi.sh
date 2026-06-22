#!/usr/bin/env bash

# PassRofi — Rofi Password & TOTP Manager
# Uses pass as single source of truth
# Keybindings in rofi:
#   Enter   = Copy mode (password → clipboard, then username)
#   Alt+1   = Auto-type (username, tab, password, enter)
#   Alt+2   = Copy TOTP code
#   Alt+3   = Submenu (all options)

set -euo pipefail

# Spawned from niri (non-login shell) so .profile isn't sourced — set the
# gnupg home explicitly or gpg falls back to ~/.gnupg and can't find the key.
export GNUPGHOME="${GNUPGHOME:-${XDG_DATA_HOME:-$HOME/.local/share}/gnupg}"

STORE_DIR="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
WEB_DIR="$STORE_DIR/web"
CLIP_TIMEOUT=45
CLIP_SWITCH=10
TIMER_PID_FILE="/tmp/passrofi-timer.pid"

# ── Helpers ──────────────────────────────────────────────────────────────────

notify() {
    notify-send -a "PassRofi" -t "${2:-3000}" "$1"
}

# Kill any previous clipboard timer
kill_timer() {
    if [[ -f "$TIMER_PID_FILE" ]]; then
        local pid
        pid=$(<"$TIMER_PID_FILE")
        kill "$pid" 2>/dev/null || true
        rm -f "$TIMER_PID_FILE"
    fi
}

# Get password entry fields
get_field() {
    local entry="$1" field="$2"
    local content
    content=$(pass show "$entry" 2>/dev/null) || return 1

    case "$field" in
    password)
        echo "$content" | head -1
        ;;
    username)
        echo "$content" | grep -i "^username:" | head -1 | sed 's/^[Uu]sername:[[:space:]]*//'
        ;;
    url)
        echo "$content" | grep -i "^url:" | head -1 | sed 's/^[Uu]rl:[[:space:]]*//'
        ;;
    autotype)
        local seq
        seq=$(echo "$content" | grep -i "^autotype:" | head -1 | sed 's/^[Aa]utotype:[[:space:]]*//')
        echo "${seq:-username :tab password :enter}"
        ;;
    has_otp)
        echo "$content" | grep -q "^otpauth://" && echo "yes" || echo "no"
        ;;
    esac
}

# List all web entries as "domain — username"
list_entries() {
    if [[ ! -d "$WEB_DIR" ]]; then
        return
    fi
    find "$WEB_DIR" -name "*.gpg" -type f | sort | while read -r gpg_file; do
        local rel="${gpg_file#$WEB_DIR/}"
        rel="${rel%.gpg}"
        local domain="${rel%%/*}"
        local user="${rel#*/}"
        echo " $domain — $user"
    done
}

# ── Smart Window Matching ────────────────────────────────────────────────────

get_focused_domain() {
    local win_info
    win_info=$(niri msg focused-window 2>/dev/null) || return 1

    # Only autofill from browser windows — otherwise titles like
    # "start_tmux.sh" get mistaken for a domain and prefill the search.
    local app_id
    app_id=$(echo "$win_info" | grep "App ID:" | sed 's/.*App ID: "\(.*\)"/\1/')
    echo "$app_id" | grep -qiE 'zen|chrom|firefox|qutebrowser|thorium|brave|browser' || return 0

    local title
    title=$(echo "$win_info" | grep "Title:" | sed 's/.*Title: "\(.*\)"/\1/')

    # Try to extract domain from browser title
    # Common patterns: "Page Title - domain.com - Browser" or "domain.com/path"
    local domain=""

    # Match domain-like patterns in the title
    domain=$(echo "$title" | grep -oP '[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}(\.[a-zA-Z]{2,})?' | head -1)

    echo "$domain"
}

# ── Main Menu ────────────────────────────────────────────────────────────────

main_menu() {
    local focused_domain
    focused_domain=$(get_focused_domain)

    # Build entry list
    local entries
    entries=$(list_entries)

    # Build full menu with action items at top
    local menu
    menu=$(printf "%s\n%s\n%s\n%s" \
        "+ Add Password" \
        "+ Add TOTP" \
        "──────────────" \
        "$entries")

    # If we have a focused domain match, use it as rofi filter
    local rofi_args=(-dmenu -i -p " " -theme black
        -kb-custom-1 "Alt+1"
        -kb-custom-2 "Alt+2"
        -kb-custom-3 "Alt+3,Shift+Return"
        -kb-accept-alt "")

    if [[ -n "$focused_domain" ]]; then
        rofi_args+=(-filter "$focused_domain")
    fi

    local selected exit_code
    selected=$(echo "$menu" | rofi "${rofi_args[@]}") && exit_code=$? || exit_code=$?

    # Empty selection
    [[ -z "$selected" ]] && exit 0

    # Handle action items and separator
    case "$selected" in
    "+ Add Password")
        add_password
        return
        ;;
    "+ Add TOTP")
        add_totp
        return
        ;;
    "──────────────")
        main_menu
        return
        ;;
    esac

    # Parse selected entry: " domain — username" → "web/domain/username"
    local stripped="${selected#* }" # Remove icon prefix
    local domain="${stripped%% — *}"
    local user="${stripped##* — }"
    local entry="web/$domain/$user"

    # Handle based on exit code
    case "$exit_code" in
    0) # Enter — Copy mode
        copy_mode "$entry"
        ;;
    10) # Alt+1 — Auto-type
        auto_type "$entry"
        ;;
    11) # Alt+2 — Copy TOTP
        copy_totp "$entry"
        ;;
    12) # Alt+3 — Submenu
        submenu "$entry"
        ;;
    esac
}

# ── Copy Mode ────────────────────────────────────────────────────────────────

copy_mode() {
    local entry="$1"

    kill_timer

    local password username
    password=$(get_field "$entry" "password")
    username=$(get_field "$entry" "username")

    if [[ -z "$password" ]]; then
        notify " No password found for $entry"
        return 1
    fi

    # Copy password then username (both land in clipboard history)
    echo -n "$password" | wl-copy
    [[ -n "$username" ]] && echo -n "$username" | wl-copy
    notify-send -a "PassRofi" -t 3000 " Password & username copied (clearing in ${CLIP_TIMEOUT}s)"

    # Background timer: clear clipboard
    (
        sleep "$CLIP_TIMEOUT"
        wl-copy --clear
        notify-send -a "PassRofi" -t 2000 " Clipboard cleared"
        rm -f "$TIMER_PID_FILE"
    ) &
    echo $! >"$TIMER_PID_FILE"
}

# ── Copy TOTP ────────────────────────────────────────────────────────────────

copy_totp() {
    local entry="$1"

    local has_otp
    has_otp=$(get_field "$entry" "has_otp")

    if [[ "$has_otp" != "yes" ]]; then
        notify " No TOTP configured for this entry"
        return 1
    fi

    kill_timer

    local code remaining
    code=$(pass otp "$entry" 2>/dev/null)
    remaining=$((30 - $(date +%s) % 30))
    echo -n "$code" | wl-copy
    notify " TOTP copied: $code (expires in ${remaining}s)"

    (
        sleep "$CLIP_TIMEOUT"
        wl-copy --clear
        notify-send -a "PassRofi" -t 2000 " Clipboard cleared"
        rm -f "$TIMER_PID_FILE"
    ) &
    echo $! >"$TIMER_PID_FILE"
}

# ── Auto-type ────────────────────────────────────────────────────────────────

auto_type() {
    local entry="$1"

    local password username sequence
    password=$(get_field "$entry" "password")
    username=$(get_field "$entry" "username")
    sequence=$(get_field "$entry" "autotype")

    # Small delay for focus to return to original window
    sleep 0.1

    # Parse and execute autotype sequence
    local IFS=' '
    read -ra tokens <<<"$sequence"

    local i=0
    while [[ $i -lt ${#tokens[@]} ]]; do
        local token="${tokens[$i]}"
        case "$token" in
        username)
            wtype -- "$username"
            ;;
        password)
            wtype -- "$password"
            ;;
        otp)
            local code
            code=$(pass otp "$entry" 2>/dev/null) || {
                notify " TOTP generation failed"
                return 1
            }
            wtype -- "$code"
            ;;
        :tab)
            wtype -k Tab
            ;;
        :enter)
            wtype -k Return
            ;;
        :delay)
            i=$((i + 1))
            local secs="${tokens[$i]:-1}"
            sleep "$secs"
            ;;
        *)
            # Unknown token — type it literally
            wtype -- "$token"
            ;;
        esac
        i=$((i + 1))
    done
}

# ── Submenu ──────────────────────────────────────────────────────────────────

submenu() {
    local entry="$1"

    local has_otp
    has_otp=$(get_field "$entry" "has_otp")

    local options=" Copy Password\n Copy Username"
    if [[ "$has_otp" == "yes" ]]; then
        options="$options\n Copy TOTP\n Remove TOTP"
    fi
    options="$options\n Auto-type\n Edit Autotype\n Edit\n Delete"

    local selected
    selected=$(echo -e "$options" | rofi -dmenu -i -p " $entry" -theme black)

    [[ -z "$selected" ]] && return 0

    case "$selected" in
    " Copy Password")
        local pw
        pw=$(get_field "$entry" "password")
        echo -n "$pw" | wl-copy
        notify " Password copied (clearing in ${CLIP_TIMEOUT}s)"
        (
            sleep "$CLIP_TIMEOUT"
            wl-copy --clear
        ) &
        ;;
    " Copy Username")
        local user
        user=$(get_field "$entry" "username")
        echo -n "$user" | wl-copy
        notify " Username copied (clearing in ${CLIP_TIMEOUT}s)"
        (
            sleep "$CLIP_TIMEOUT"
            wl-copy --clear
        ) &
        ;;
    " Copy TOTP")
        copy_totp "$entry"
        ;;
    " Remove TOTP")
        local confirm
        confirm=$(printf "Yes\nNo" | rofi -dmenu -p " Remove TOTP from $entry?" -theme power)
        if [[ "$confirm" == "Yes" ]]; then
            local content
            content=$(pass show "$entry" 2>/dev/null)
            local new_content
            new_content=$(echo "$content" | grep -v "^otpauth://")
            echo "$new_content" | pass insert -m -f "$entry"
            notify " TOTP removed from $entry"
        fi
        ;;
    " Auto-type")
        auto_type "$entry"
        ;;
    " Edit Autotype")
        edit_autotype "$entry"
        ;;
    " Edit")
        ghostty -e bash -c "pass edit '$entry'"
        ;;
    " Delete")
        local confirm
        confirm=$(printf "Yes\nNo" | rofi -dmenu -p " Delete $entry?" -theme power)
        if [[ "$confirm" == "Yes" ]]; then
            pass rm -f "$entry"
            notify " Deleted $entry"
        fi
        ;;
    esac
}

edit_autotype() {
    local entry="$1"

    local current_seq
    current_seq=$(get_field "$entry" "autotype")

    local new_seq
    new_seq=$(rofi -dmenu -p " Autotype sequence" -filter "$current_seq" -theme black)

    [[ -z "$new_seq" ]] && return 0

    # Rewrite the entry with updated autotype line
    local content
    content=$(pass show "$entry" 2>/dev/null)

    # Remove old autotype line if present, add new one
    local new_content
    new_content=$(echo "$content" | grep -iv "^autotype:")
    new_content="$new_content
autotype: $new_seq"

    echo "$new_content" | pass insert -m -f "$entry"
    notify " Autotype updated"
}

# ── Add Password ─────────────────────────────────────────────────────────────

add_password() {
    local url username password domain

    # Prompt for URL
    url=$(rofi -dmenu -p " URL" -theme black)
    [[ -z "$url" ]] && return 0

    # Prompt for username
    username=$(rofi -dmenu -p " Username" -theme black)
    [[ -z "$username" ]] && return 0

    # Prompt for password (masked input)
    password=$(rofi -dmenu -p " Password (empty=generate)" -password -theme black) || true

    # Extract domain from URL
    domain=$(echo "$url" | sed -E 's|https?://||; s|www\.||; s|/.*||')

    # Generate password if empty
    if [[ -z "$password" ]]; then
        password=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 24)
        echo -n "$password" | wl-copy
        notify " Password generated and copied to clipboard" 5000
    fi

    local entry="web/$domain/$username"

    # Check if entry already exists
    if pass show "$entry" &>/dev/null; then
        local overwrite
        overwrite=$(printf "Yes\nNo" | rofi -dmenu -p " Entry exists. Overwrite?" -theme power)
        [[ "$overwrite" != "Yes" ]] && return 0
    fi

    # Create the entry
    printf '%s\nurl: %s\nusername: %s\n' "$password" "$url" "$username" | pass insert -m -f "$entry"

    notify " Added $entry"
}

# ── Add TOTP ─────────────────────────────────────────────────────────────────

add_totp() {
    local method
    method=$(printf " Scan QR from screen\n Enter URI manually\n Import from file" |
        rofi -dmenu -p " Add TOTP" -theme black)

    [[ -z "$method" ]] && return 0

    case "$method" in
    " Scan QR from screen")
        totp_scan_qr
        ;;
    " Enter URI manually")
        totp_manual
        ;;
    " Import from file")
        totp_import_file
        ;;
    esac
}

totp_scan_qr() {
    local geometry uri

    # Select screen region
    geometry=$(slurp 2>/dev/null) || {
        notify " QR scan cancelled"
        return 1
    }

    # Capture and decode
    grim -g "$geometry" /tmp/passrofi-qr.png
    uri=$(zbarimg --raw -q /tmp/passrofi-qr.png 2>/dev/null) || {
        rm -f /tmp/passrofi-qr.png
        notify " No QR code found in selection"
        return 1
    }
    rm -f /tmp/passrofi-qr.png

    if [[ "$uri" != otpauth://* ]]; then
        notify " Invalid QR: not an otpauth:// URI"
        return 1
    fi

    totp_attach_uri "$uri"
}

totp_manual() {
    local uri
    uri=$(rofi -dmenu -p " otpauth:// URI" -theme black)
    [[ -z "$uri" ]] && return 0

    if [[ "$uri" != otpauth://* ]]; then
        notify " Invalid URI: must start with otpauth://"
        return 1
    fi

    totp_attach_uri "$uri"
}

totp_import_file() {
    # Show files from Desktop and Downloads
    local files
    files=$(find "$HOME/Desktop" "$HOME/Downloads" \
        -maxdepth 2 -type f \
        \( -name "*.txt" -o -name "*.json" -o -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.svg" \) \
        2>/dev/null | sort -t/ -k+5)

    [[ -z "$files" ]] && {
        notify " No importable files found"
        return 1
    }

    local selected
    selected=$(echo "$files" | rofi -dmenu -p " Select file" -theme black)
    [[ -z "$selected" ]] && return 0

    local ext="${selected##*.}"

    case "$ext" in
    png | jpg | jpeg | svg)
        # Image file — decode QR
        local uri
        uri=$(zbarimg --raw -q "$selected" 2>/dev/null) || {
            notify " No QR code found in image"
            return 1
        }
        if [[ "$uri" != otpauth://* ]]; then
            notify " Invalid QR: not an otpauth:// URI"
            return 1
        fi
        totp_attach_uri "$uri"
        ;;
    txt)
        # Text file — read otpauth:// URIs line by line
        local count=0
        while IFS= read -r line; do
            if [[ "$line" == otpauth://* ]]; then
                totp_attach_uri "$line"
                count=$((count + 1))
            fi
        done <"$selected"
        if [[ $count -eq 0 ]]; then
            notify " No otpauth:// URIs found in file"
        else
            notify " Imported $count TOTP entries"
        fi
        ;;
    json)
        # JSON file — extract otpauth:// URIs from authenticator exports
        # Supports: Aegis, 2FAS, andOTP, and generic {entries[].content.uri} format
        local uris
        uris=$(python3 -c "
import json, sys
with open('$selected') as f:
    data = json.load(f)
# Try common JSON formats
entries = []
if 'entries' in data:
    # Aegis / generic format
    for e in data['entries']:
        uri = e.get('content', {}).get('uri') or e.get('info', {}).get('uri') or e.get('uri', '')
        if uri.startswith('otpauth://'):
            entries.append(uri)
elif 'services' in data:
    # 2FAS format
    for s in data['services']:
        uri = s.get('otp', {}).get('link', '') or s.get('secret', '')
        if uri.startswith('otpauth://'):
            entries.append(uri)
elif isinstance(data, list):
    # andOTP format
    for e in data:
        uri = e.get('uri', '')
        if uri.startswith('otpauth://'):
            entries.append(uri)
for u in entries:
    print(u)
" 2>/dev/null)
        if [[ -z "$uris" ]]; then
            notify " No otpauth:// URIs found in JSON"
            return 1
        fi
        local count=0
        while IFS= read -r uri; do
            totp_attach_uri "$uri"
            count=$((count + 1))
        done <<<"$uris"
        notify " Imported $count TOTP entries from JSON"
        ;;
    esac
}

totp_attach_uri() {
    local uri="$1"

    # Parse issuer and account from URI
    # Format: otpauth://totp/Issuer:account?secret=...&issuer=...
    local label
    label=$(echo "$uri" | sed -E 's|otpauth://[a-z]+/||; s|\?.*||')
    local issuer account
    if [[ "$label" == *:* ]]; then
        issuer="${label%%:*}"
        account="${label#*:}"
    else
        issuer="$label"
        account="$label"
    fi

    # URL-decode
    issuer=$(printf '%b' "${issuer//%/\\x}")
    account=$(printf '%b' "${account//%/\\x}")

    notify " Found TOTP: $issuer ($account)"

    # Let user pick an existing entry to attach to, or create new
    local entries
    entries=$(list_entries)
    local menu
    menu=$(printf "+ Create new entry\n%s" "$entries")

    local selected
    selected=$(echo "$menu" | rofi -dmenu -p " Attach TOTP to" -theme black)
    [[ -z "$selected" ]] && return 0

    local entry
    if [[ "$selected" == "+ Create new entry" ]]; then
        # Use issuer as domain, account as username
        local domain="${issuer,,}" # lowercase
        domain=$(echo "$domain" | sed 's/ /-/g')
        entry="web/$domain/$account"

        # Create a minimal entry
        printf 'CHANGE_ME\nurl: https://%s\nusername: %s\n' "$domain" "$account" |
            pass insert -m -f "$entry"
    else
        local stripped="${selected#* }"
        local domain="${stripped%% — *}"
        local user="${stripped##* — }"
        entry="web/$domain/$user"
    fi

    # Append OTP URI using pass-otp
    echo "$uri" | pass otp append -s "$entry" 2>/dev/null || {
        # If append fails (entry may not have otp yet), try insert
        echo "$uri" | pass otp insert -s -f "$entry" 2>/dev/null || {
            notify " Failed to add TOTP to $entry"
            return 1
        }
    }

    # Verify
    local code
    code=$(pass otp "$entry" 2>/dev/null) || {
        notify " TOTP added but verification failed"
        return 1
    }

    notify " TOTP added to $entry (code: $code)" 5000
}

# ── Entry Point ──────────────────────────────────────────────────────────────

main_menu
