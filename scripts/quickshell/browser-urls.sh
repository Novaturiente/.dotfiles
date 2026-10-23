#!/usr/bin/env bash
# Emit novabrowser bookmarks + history as a JSON array for the Quickshell url menu.
# Each element: {"title":..., "url":..., "icon":..., "bookmark":bool}
# Bookmarks: ~/.config/novabrowser/bookmarks/urls ("url title" per line, qutebrowser format).
# History:   ~/.local/share/novabrowser/history.sqlite, ranked the way the browser ranks it.
# shortcut: no favicons (novabrowser keeps them in CEF's cache, not a readable db), "icon" is always "".
set -euo pipefail

DELIM=$'\t'
BOOKMARKS="${XDG_CONFIG_HOME:-$HOME/.config}/novabrowser/bookmarks/urls"
DB="${XDG_DATA_HOME:-$HOME/.local/share}/novabrowser/history.sqlite"

LIST=""
if [[ -f "$BOOKMARKS" ]]; then
    # "url title..." -> 1<TAB>title<TAB>url (title falls back to url)
    LIST=$(awk -v d="$DELIM" 'NF { u=$1; $1=""; t=substr($0,2); print "1" d (t=="" ? u : t) d u }' "$BOOKMARKS")
fi

if [[ -f "$DB" ]]; then
    # copy db+wal so the latest committed rows are visible without locking the live db
    TMP=$(mktemp -d)
    cp "$DB" "$TMP/h.sqlite" 2>/dev/null || true
    [[ -f "$DB-wal" ]] && cp "$DB-wal" "$TMP/h.sqlite-wal" 2>/dev/null || true
    HIST=$(sqlite3 "$TMP/h.sqlite" "
        SELECT '0' || '$DELIM' || IFNULL(NULLIF(title,''), url) || '$DELIM' || url
        FROM history WHERE url LIKE 'http%'
        ORDER BY typed DESC, visits DESC, id DESC LIMIT 500;" 2>/dev/null || true)
    rm -rf "$TMP"
    LIST=$(printf '%s\n%s' "$LIST" "$HIST")
fi

# dedup by url (last field); keep first occurrence (bookmark wins over history)
awk -F"$DELIM" 'NF>=3 && !seen[$3]++' <<< "$LIST" \
    | jq -Rn '[inputs | split("\t") | {bookmark:(.[0]=="1"), title:.[1], url:.[2], icon:""}]'
