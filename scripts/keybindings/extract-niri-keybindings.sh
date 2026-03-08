#!/usr/bin/env bash
#
# Extract keybindings from niri config.kdl and write bindings/niri.txt
# so the keybindings menu shows your current niri shortcuts.
#
# Usage: extract-niri-keybindings.sh [config.kdl]
#   Default config: $NIRI_CONFIG or $HOME/.config/niri/config.kdl

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINDINGS_DIR="${SCRIPT_DIR}/bindings"
OUT_FILE="${BINDINGS_DIR}/niri.txt"
CONFIG="${1:-${NIRI_CONFIG:-$HOME/.config/niri/config.kdl}}"

if [[ ! -f "$CONFIG" ]]; then
    echo "Error: config not found: $CONFIG" >&2
    exit 1
fi

# Extract hotkey-overlay-title="..." from line (print the quoted value)
get_title() {
    local line="$1"
    if [[ "$line" =~ hotkey-overlay-title=\"([^\"]*)\" ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

# Shorten spawn/spawn-sh to a readable action (first quoted arg or script name)
shorten_spawn() {
    local line="$1"
    line="${line#"${line%%[![:space:]]*}"}"  # trim leading space
    line="${line%;}"                          # remove trailing ;
    if [[ "$line" =~ spawn(-sh)?[[:space:]]+\"([^\"]+)\" ]]; then
        local cmd="${BASH_REMATCH[2]}"
        # Show script name or last path component
        if [[ "$cmd" == *"/"* ]]; then
            echo "${cmd##*/}"
        else
            echo "$cmd"
        fi
        return
    fi
    # spawn "a" "b" "c" ...
    if [[ "$line" =~ spawn(-sh)?[[:space:]]+\"([^\"]+)\".*\"([^\"]+)\" ]]; then
        echo "${BASH_REMATCH[3]}"
        return
    fi
    echo "$line"
}

in_binds=0
depth=0
key=""
title=""
expect_action=0
actions=()

mkdir -p "$BINDINGS_DIR"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

while IFS= read -r line; do
    # Skip full-line comments
    if [[ "$line" =~ ^[[:space:]]*// ]]; then
        continue
    fi

    if [[ "$line" =~ ^[[:space:]]*binds[[:space:]]+\{[[:space:]]*$ ]]; then
        in_binds=1
        depth=1
        continue
    fi

    if [[ $in_binds -eq 0 ]]; then
        continue
    fi

    # Closing brace
    if [[ "$line" =~ ^[[:space:]]*\}[[:space:]]* ]]; then
        if [[ $expect_action -eq 1 && -n "$key" ]]; then
            # We had key and were waiting for action; the action is in actions array
            action_line="${actions[*]}"
            action_line="${action_line#"${action_line%%[![:space:]]*}"}"
            action_line="${action_line%;}"
            if [[ -n "$title" ]]; then
                action="$title"
            elif [[ "$action_line" =~ ^spawn ]]; then
                action=$(shorten_spawn "$action_line")
            else
                action="$action_line"
            fi
            printf '%s\t%s\n' "$key" "$action" >> "$tmp"
        fi
        key=""
        title=""
        expect_action=0
        actions=()
        depth=$((depth - 1))
        if [[ $depth -eq 0 ]]; then
            in_binds=0
        fi
        continue
    fi

    # Line contains opening brace: start of a new bind
    if [[ "$line" == *"{"* ]] && [[ "$line" != *"}"* ]]; then
        # Key is the first token (trim leading space, then take until next space)
        key="${line#"${line%%[![:space:]]*}"}"
        key="${key%%[[:space:]]*}"
        key="${key%%\{*}"
        [[ -z "$key" || "$key" == "binds" ]] && continue
        title=$(get_title "$line")
        expect_action=1
        actions=()
        depth=$((depth + 1))
        continue
    fi

    # We're inside a bind block waiting for the action line(s)
    if [[ $expect_action -eq 1 && -n "$key" ]]; then
        actions+=("$line")
    fi
done < "$CONFIG"

# Sort by key for consistent output
sort -t$'\t' -k1 -o "$tmp" "$tmp"

# Pad key column so keybindings align in rofi (like csvlens: key  action)
key_width=$(awk -F'\t' 'max < length($1) { max = length($1) } END { print max + 0 }' "$tmp")
[[ -z "$key_width" || "$key_width" -lt 20 ]] && key_width=28
awk -F'\t' -v "w=$key_width" '{ printf "%-*s  %s\n", w, $1, $2 }' "$tmp" > "$OUT_FILE"

echo "Updated $OUT_FILE from $CONFIG ($(wc -l < "$OUT_FILE") keybindings)"
