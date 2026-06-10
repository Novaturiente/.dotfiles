#!/usr/bin/env bash
# Rofi url-bar: shows bookmarks + history as suggestions, opens picks/typed
# input in Firefox.
#   - pick an entry            -> open its url
#   - type a url / bare domain -> opened directly (localhost -> http://)
#   - anything else            -> Google search
# Suggestions come from the LIVE Firefox default profile only, so they match
# exactly what Firefox shows (no stale data from other profiles/browsers).
set -euo pipefail

BROWSER="firefox"
SEARCH="https://www.google.com/search?q="
DELIM=" ::: "                       # visible separator between title and url

# Firefox profile roots, in order. This Firefox stores profiles under XDG
# (~/.config/mozilla), with ~/.mozilla as the classic fallback.
FF_ROOTS=("$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox")

# Bookmarks first: ★ + name + url (names are curated/unique).
# History after: url only (titles collide; the url is what identifies the page).
# Either way the url is the last DELIM-field (history has no DELIM -> whole line),
# so dedup-by-url and pick-resolution both work.
SQL="
SELECT '★ ' || IFNULL(NULLIF(b.title,''), p.url) || '$DELIM' || p.url
FROM moz_bookmarks b
JOIN moz_places p ON b.fk = p.id
LEFT JOIN moz_bookmarks par ON b.parent = par.id
WHERE b.type = 1 AND p.url LIKE 'http%'
  AND IFNULL(par.title,'') <> 'Mozilla Firefox'
ORDER BY p.frecency DESC;
SELECT p.url
FROM moz_places p
WHERE p.url LIKE 'http%' AND p.hidden = 0 AND p.visit_count > 0
ORDER BY p.frecency DESC LIMIT 500;
"

# ── locate the live default profile's places.sqlite ─────────────────────────
FF_ROOT=""
for r in "${FF_ROOTS[@]}"; do
    [[ -f "$r/profiles.ini" ]] && { FF_ROOT="$r"; break; }
done

DB=""
if [[ -n "$FF_ROOT" ]]; then
    # the profile Firefox actually launches = Default= under [InstallXXXX]
    prof=$(awk -F= '
        /^\[Install/{inst=1; next}
        /^\[/{inst=0}
        inst && /^Default=/{print $2; exit}
    ' "$FF_ROOT/profiles.ini")
    [[ -n "${prof:-}" && -f "$FF_ROOT/$prof/places.sqlite" ]] && DB="$FF_ROOT/$prof/places.sqlite"
    # fallback: newest places.sqlite under the root
    if [[ -z "$DB" ]]; then
        DB=$( { find "$FF_ROOT" -maxdepth 2 -name places.sqlite -printf '%T@ %p\n' 2>/dev/null \
            || true; } | sort -rn | head -1 | cut -d' ' -f2-)
    fi
fi

# ── query that one profile (copy db+wal so we see latest, applied WAL) ───────
LIST=""
if [[ -n "$DB" && -f "$DB" ]]; then
    TMP=$(mktemp -d)
    cp "$DB" "$TMP/places.sqlite" 2>/dev/null || true
    [[ -f "$DB-wal" ]] && cp "$DB-wal" "$TMP/places.sqlite-wal" 2>/dev/null || true
    [[ -f "$DB-shm" ]] && cp "$DB-shm" "$TMP/places.sqlite-shm" 2>/dev/null || true
    # plain RW on the throwaway copy so SQLite applies the WAL (immutable would skip it)
    LIST=$(sqlite3 "$TMP/places.sqlite" "$SQL" 2>/dev/null \
        | awk -F"$DELIM" 'NF && !seen[$NF]++')
    rm -rf "$TMP"
fi

# ── favicons: build host -> best icon map from favicons.sqlite ──────────────
ICON_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/firefox-url-icons"
mkdir -p "$ICON_DIR"
FAV="${DB%/places.sqlite}/favicons.sqlite"
declare -A HOST_ICON                       # host -> "score|icon_id"
FAVTMP=""
if [[ -n "$DB" && -f "$FAV" ]]; then
    FAVTMP=$(mktemp -d)
    cp "$FAV" "$FAVTMP/f" 2>/dev/null || true
    [[ -f "$FAV-wal" ]] && cp "$FAV-wal" "$FAVTMP/f-wal" 2>/dev/null || true
    while IFS='|' read -r purl iid width root; do
        [[ -z "$purl" || -z "$iid" ]] && continue
        host=${purl#*://}; host=${host%%/*}
        [[ -z "$host" ]] && continue
        score=$width; [[ "$root" == "1" ]] && score=$((score + 100000))
        cur=${HOST_ICON[$host]:-}
        [[ -z "$cur" || "$score" -gt "${cur%%|*}" ]] && HOST_ICON[$host]="$score|$iid"
    done < <(sqlite3 "$FAVTMP/f" "SELECT p.page_url,i.id,i.width,i.root \
        FROM moz_pages_w_icons p \
        JOIN moz_icons_to_pages tp ON tp.page_id=p.id \
        JOIN moz_icons i ON i.id=tp.icon_id;" 2>/dev/null || true)
fi

# echo a cached icon-file path for a host (extracting the blob on first use)
icon_for() {
    local host="$1" val iid e magic ext
    val=${HOST_ICON[$host]:-}; [[ -z "$val" ]] && return 0
    iid=${val##*|}
    for e in svg png ico; do
        [[ -f "$ICON_DIR/$iid.$e" ]] && { printf '%s' "$ICON_DIR/$iid.$e"; return 0; }
    done
    [[ -z "$FAVTMP" ]] && return 0
    magic=$(sqlite3 "$FAVTMP/f" "SELECT hex(substr(data,1,4)) FROM moz_icons WHERE id=$iid;" 2>/dev/null || true)
    case "$magic" in 89504E47*) ext=png;; 3C*|EFBB*) ext=svg;; 00000100*) ext=ico;; *) ext=png;; esac
    sqlite3 "$FAVTMP/f" "SELECT writefile('$ICON_DIR/$iid.$ext', data) FROM moz_icons WHERE id=$iid;" \
        >/dev/null 2>&1 || return 0
    printf '%s' "$ICON_DIR/$iid.$ext"
}

# ── prompt (per-row favicons) ───────────────────────────────────────────────
# Tab / Ctrl+Space drops the highlighted entry into the input box so you can
# edit it before opening (arrows still navigate the list).
CHOICE=$(
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" == *"$DELIM"* ]]; then u="${line##*$DELIM}"; else u="$line"; fi
        h=${u#*://}; h=${h%%/*}
        ic=$(icon_for "$h")
        if [[ -n "$ic" ]]; then printf '%s\0icon\x1f%s\n' "$line" "$ic"
        else printf '%s\n' "$line"; fi
    done <<< "$LIST" \
    | rofi -dmenu -i -p "Firefox" -theme black -show-icons \
        -theme-str 'window { width: 750px; } element-icon { size: 1.0em; }' \
        -kb-element-next "" -kb-row-select "Tab,Control+space"
) || { [[ -n "$FAVTMP" ]] && rm -rf "$FAVTMP"; exit 0; }
[[ -n "$FAVTMP" ]] && rm -rf "$FAVTMP"
[[ -z "${CHOICE:-}" ]] && exit 0

# ── resolve to a URL ─────────────────────────────────────────────────────────
if [[ "$CHOICE" == *"$DELIM"* ]]; then
    URL="${CHOICE##*$DELIM}"                       # picked an existing entry
else
    IN="$CHOICE"
    if [[ "$IN" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
        URL="$IN"                                  # already has a scheme
    elif [[ "$IN" != *" "* && "$IN" =~ ^(localhost|127\.0\.0\.1)(:[0-9]+)?(/.*)?$ ]]; then
        URL="http://$IN"                           # local dev server
    elif [[ "$IN" != *" "* && "$IN" =~ ^[^[:space:]]+\.[a-zA-Z]{2,}(:[0-9]+)?(/.*)?$ ]]; then
        URL="https://$IN"                          # looks like a bare domain
    else
        Q=$(printf '%s' "$IN" | sed 's/ /+/g')     # search term
        URL="${SEARCH}${Q}"
    fi
fi

# ── focus the firefox window the tab landed in ──────────────────────────────
# Niri doesn't auto-focus on Firefox's activation request, so do it over IPC.
#  - firefox already running -> tab reuses an existing window: focus the most
#    recently used firefox window right away.
#  - cold start / new-window  -> poll until a brand-new firefox window appears,
#    then focus that one.
focus_firefox() {
    local before now new id
    before=$(niri msg --json windows 2>/dev/null \
        | jq -c '[.[] | select(.app_id=="firefox") | .id]' 2>/dev/null || echo '[]')
    for _ in $(seq 1 50); do                       # up to ~5s, exits early
        now=$(niri msg --json windows 2>/dev/null || true)
        [[ -z "$now" ]] && { sleep 0.1; continue; }
        new=$(jq -r --argjson b "$before" \
            '[.[] | select(.app_id=="firefox")]
             | map(select((.id as $i | $b | index($i)) | not))
             | sort_by(.id) | last | .id // empty' <<<"$now" 2>/dev/null || true)
        if [[ -n "$new" ]]; then
            niri msg action focus-window --id "$new" >/dev/null 2>&1 || true
            return
        fi
        if [[ "$before" != "[]" ]]; then           # reused an existing window
            id=$(jq -r '[.[] | select(.app_id=="firefox")]
                 | sort_by(.focus_timestamp.secs) | last | .id // empty' \
                 <<<"$now" 2>/dev/null || true)
            [[ -n "$id" ]] && niri msg action focus-window --id "$id" >/dev/null 2>&1 || true
            return
        fi
        sleep 0.1
    done
}

setsid "$BROWSER" "$URL" >/dev/null 2>&1 &
focus_firefox
