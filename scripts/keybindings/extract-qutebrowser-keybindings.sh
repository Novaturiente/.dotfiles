#!/usr/bin/env bash
#
# Build a single qutebrowser keybindings list:
#   - Base = default keybindings (qutebrowser-default.txt)
#   - config.bind() in config.py overwrites that key's description, or adds it if new
#   - config.unbind() removes that key from the list
# Output: one file bindings/qutebrowser.txt (default + your overrides and new bindings).
#
# Usage: extract-qutebrowser-keybindings.sh [config.py]
#   Default: $QUTEBROWSER_CONFIG or $HOME/.config/qutebrowser/config.py

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINDINGS_DIR="${SCRIPT_DIR}/bindings"
DEFAULT_FILE="${BINDINGS_DIR}/qutebrowser-default.txt"
OUT_FILE="${BINDINGS_DIR}/qutebrowser.txt"
CONFIG="${1:-${QUTEBROWSER_CONFIG:-$HOME/.config/qutebrowser/config.py}}"

# Short description from command string
cmd_to_desc() {
    local cmd="$1"
    [[ -z "$cmd" ]] && echo "" && return
    if [[ "$cmd" == "mode-leave" ]]; then echo "Leave insert/passthrough mode"
    elif [[ "$cmd" =~ ^open[[:space:]]+-w ]]; then echo "New window"
    elif [[ "$cmd" =~ ^open[[:space:]]+-t ]]; then echo "Open URL in new tab"
    elif [[ "$cmd" =~ spawn.*bookmarks\.sh ]]; then echo "Add bookmark (rofi)"
    elif [[ "$cmd" =~ login-choose ]]; then echo "Login choose"
    elif [[ "$cmd" =~ login-username ]]; then echo "Login username"
    elif [[ "$cmd" =~ login-password ]]; then echo "Login password"
    elif [[ "$cmd" =~ password-add ]]; then echo "Add password"
    elif [[ "$cmd" =~ password-fill-auto ]]; then echo "Password fill auto"
    elif [[ "$cmd" =~ toggle-adblock ]]; then echo "Toggle adblock"
    elif [[ "$cmd" =~ toggle-dark-mode ]]; then echo "Toggle dark mode"
    elif [[ "$cmd" =~ toggle-mobile-view ]]; then echo "Toggle mobile view"
    elif [[ "$cmd" =~ bookmarks-search ]]; then echo "Bookmarks search"
    elif [[ "$cmd" =~ sync-toggle ]]; then echo "Sync toggle"
    elif [[ "$cmd" =~ toggle-tabs-layout ]]; then echo "Toggle tabs layout"
    elif [[ "$cmd" =~ window-clone ]]; then echo "Clone window"
    elif [[ "$cmd" =~ cmd-set-text.*:open[[:space:]]+-t ]]; then echo "Open URL in new tab (prompt)"
    elif [[ "$cmd" =~ cmd-set-text.*:open ]]; then echo "Open URL (prompt)"
    elif [[ "$cmd" =~ ^tab-next ]]; then echo "Next tab"
    elif [[ "$cmd" =~ ^tab-prev ]]; then echo "Previous tab"
    elif [[ "$cmd" =~ open[[:space:]]+-t ]]; then echo "Open URL in new tab"
    else
        echo "${cmd:0:45}"
    fi
}

# Parse config.py: config.bind("key", "command" [, mode=...]) and config.unbind("key")
declare -A custom_binds
declare -A unbinds

if [[ -f "$CONFIG" ]]; then
    block=""
    while IFS= read -r line; do
        # Skip full-line comments
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        if [[ "$line" =~ config\.(bind|unbind) ]]; then
            block="$line"
        elif [[ -n "$block" ]]; then
            block="$block $line"
        fi
        if [[ -n "$block" && "$block" =~ \) ]]; then
            if [[ "$block" =~ config\.unbind[[:space:]]*\([[:space:]]*[\"\']([^\"\']+)[\"\'] ]]; then
                unbinds["${BASH_REMATCH[1]}"]=1
            fi
            if [[ "$block" =~ config\.bind[[:space:]]*\([[:space:]]*[\"\']([^\"\']+)[\"\'][[:space:]]*,[[:space:]]*[\"\']([^\"\']*)[\"\'] ]]; then
                key="${BASH_REMATCH[1]}"
                cmd="${BASH_REMATCH[2]}"
                if [[ -n "$key" && -n "$cmd" ]]; then
                    custom_binds["$key"]=$(cmd_to_desc "$cmd")
                fi
            fi
            block=""
        fi
    done < "$CONFIG"
fi

# Start with default keybindings as the base (one list)
declare -A merged
if [[ -f "$DEFAULT_FILE" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ $'\t' ]]; then
            k="${line%%$'\t'*}"
            v="${line#*$'\t'}"
        else
            k="${line%%  *}"
            v="${line#$k}"
            v="${v#"${v%%[![:space:]]*}"}"
        fi
        [[ -n "$k" ]] && merged["$k"]="$v"
    done < "$DEFAULT_FILE"
fi

# Apply config.py: remove unbound keys, then overwrite/add from config.bind()
for k in "${!unbinds[@]}"; do
    unset 'merged[$k]'
done
for k in "${!custom_binds[@]}"; do
    merged["$k"]="${custom_binds[$k]}"
done

# Write to temp, sort, pad
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
for k in "${!merged[@]}"; do
    printf '%s\t%s\n' "$k" "${merged[$k]}"
done | sort -t$'\t' -k1 -o "$tmp"

key_width=$(awk -F'\t' 'max < length($1) { max = length($1) } END { print max + 0 }' "$tmp")
[[ -z "$key_width" || "$key_width" -lt 15 ]] && key_width=28
mkdir -p "$BINDINGS_DIR"
awk -F'\t' -v "w=$key_width" '{ printf "%-*s  %s\n", w, $1, $2 }' "$tmp" > "$OUT_FILE"

echo "Updated $OUT_FILE (base + config overrides/adds) ($(wc -l < "$OUT_FILE") keybindings)" >&2
