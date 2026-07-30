#!/usr/bin/env bash
# Open a URL in Zen and focus the window the tab landed in.
# Niri does not honor Zen's activation request, so focus over IPC.
# Usage: zen-open.sh <url-or-typed-text>
#   - full url (has scheme)  -> opened as-is
#   - localhost / bare domain-> http(s):// prefixed
#   - anything else          -> Google search
set -euo pipefail
IN="${1:?usage: zen-open.sh <url-or-text>}"
SEARCH="https://www.google.com/search?q="

if [[ "$IN" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
    URL="$IN"                                       # already a url
elif [[ "$IN" != *" "* && "$IN" =~ ^(localhost|127\.0\.0\.1)(:[0-9]+)?(/.*)?$ ]]; then
    URL="http://$IN"                                # local dev server
elif [[ "$IN" != *" "* && "$IN" =~ ^[^[:space:]]+\.[a-zA-Z]{2,}(:[0-9]+)?(/.*)?$ ]]; then
    URL="https://$IN"                               # bare domain
else
    URL="${SEARCH}$(printf '%s' "$IN" | sed 's/ /+/g')"   # search term
fi

focus_zen() {
    local before now new id
    before=$(niri msg --json windows 2>/dev/null \
        | jq -c '[.[] | select(.app_id=="zen") | .id]' 2>/dev/null || echo '[]')
    for _ in $(seq 1 50); do                       # up to ~5s, exits early
        now=$(niri msg --json windows 2>/dev/null || true)
        [[ -z "$now" ]] && { sleep 0.1; continue; }
        new=$(jq -r --argjson b "$before" \
            '[.[] | select(.app_id=="zen")]
             | map(select((.id as $i | $b | index($i)) | not))
             | sort_by(.id) | last | .id // empty' <<<"$now" 2>/dev/null || true)
        if [[ -n "$new" ]]; then
            niri msg action focus-window --id "$new" >/dev/null 2>&1 || true
            return
        fi
        if [[ "$before" != "[]" ]]; then           # reused an existing window
            id=$(jq -r '[.[] | select(.app_id=="zen")]
                 | sort_by(.focus_timestamp.secs) | last | .id // empty' \
                 <<<"$now" 2>/dev/null || true)
            [[ -n "$id" ]] && niri msg action focus-window --id "$id" >/dev/null 2>&1 || true
            return
        fi
        sleep 0.1
    done
}

setsid zen-browser "$URL" >/dev/null 2>&1 &
focus_zen
