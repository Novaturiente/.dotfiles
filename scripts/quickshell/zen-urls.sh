#!/usr/bin/env bash
# Emit Zen bookmarks + history as a JSON array for the Quickshell url menu.
# Each element: {"title":..., "url":..., "icon":..., "bookmark":bool}
# Data comes from the LIVE default Zen profile only (matches Zen's own
# suggestions). Favicons are extracted to a cache dir; "icon" is a file path
# (empty string when none). Adapted from scripts/rofi/firefox-url.sh.
set -euo pipefail

DELIM=$'\t'
ZEN_ROOTS=("$HOME/.config/zen" "$HOME/.zen")

# Bookmarks first (★, curated titles), then history (url only). Frecency order.
SQL="
SELECT '1' || '$DELIM' || IFNULL(NULLIF(b.title,''), p.url) || '$DELIM' || p.url
FROM moz_bookmarks b
JOIN moz_places p ON b.fk = p.id
LEFT JOIN moz_bookmarks par ON b.parent = par.id
WHERE b.type = 1 AND p.url LIKE 'http%'
  AND IFNULL(par.title,'') <> 'Mozilla Firefox'
ORDER BY p.frecency DESC;
SELECT '0' || '$DELIM' || IFNULL(NULLIF(p.title,''), p.url) || '$DELIM' || p.url
FROM moz_places p
WHERE p.url LIKE 'http%' AND p.hidden = 0 AND p.visit_count > 0
ORDER BY p.frecency DESC LIMIT 500;
"

# ── locate live profile's places.sqlite ─────────────────────────────────────
# profiles.ini can have multiple [InstallXXXX] blocks (multiple Zen installs);
# picking the first one's Default= often points at a stale/unused profile.
# The actively-used profile is whichever places.sqlite was written to most
# recently, so just take the newest one across all roots.
DB=$( { for r in "${ZEN_ROOTS[@]}"; do
            [[ -d "$r" ]] || continue
            find "$r" -maxdepth 2 -name places.sqlite -printf '%T@ %p\n' 2>/dev/null
        done
    } | sort -rn | head -1 | cut -d' ' -f2-)

# ── query that profile (copy db+wal so latest committed rows are visible) ────
LIST=""
if [[ -n "$DB" && -f "$DB" ]]; then
    TMP=$(mktemp -d)
    cp "$DB" "$TMP/places.sqlite" 2>/dev/null || true
    [[ -f "$DB-wal" ]] && cp "$DB-wal" "$TMP/places.sqlite-wal" 2>/dev/null || true
    [[ -f "$DB-shm" ]] && cp "$DB-shm" "$TMP/places.sqlite-shm" 2>/dev/null || true
    # dedup by url (last field); keep first occurrence (bookmark wins over history)
    LIST=$(sqlite3 "$TMP/places.sqlite" "$SQL" 2>/dev/null \
        | awk -F"$DELIM" 'NF>=3 && !seen[$3]++')
    rm -rf "$TMP"
fi

# ── favicons: host -> best icon (root/large wins) ───────────────────────────
ICON_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zen-url-icons"
mkdir -p "$ICON_DIR"
FAV="${DB%/places.sqlite}/favicons.sqlite"
declare -A HOST_ICON
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

# ── emit JSON (jq builds it so escaping is correct) ─────────────────────────
{
    while IFS="$DELIM" read -r bm title url; do
        [[ -z "$url" ]] && continue
        h=${url#*://}; h=${h%%/*}
        printf '%s\t%s\t%s\t%s\n' "$bm" "$title" "$url" "$(icon_for "$h")"
    done <<< "$LIST"
} | jq -Rn '[inputs | split("\t") | {bookmark:(.[0]=="1"), title:.[1], url:.[2], icon:.[3]}]'

[[ -n "$FAVTMP" ]] && rm -rf "$FAVTMP"
