#!/usr/bin/env bash
#
# Build a single tmux keybindings list:
#   - Base = default keybindings (tmux-default.txt)
#   - bind-key/bind in config overwrite or add entries; unbind-key/unbind remove keys
# Output: bindings/tmux.txt (one list: default + config overrides/adds).
#
# Usage: extract-tmux-keybindings.sh [tmux.conf]
#   Default: $TMUX_CONFIG or $HOME/.tmux.conf

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINDINGS_DIR="${SCRIPT_DIR}/bindings"
DEFAULT_FILE="${BINDINGS_DIR}/tmux-default.txt"
OUT_FILE="${BINDINGS_DIR}/tmux.txt"
CONFIG="${1:-${TMUX_CONFIG:-$HOME/.tmux.conf}}"

# Short description from tmux command
cmd_to_desc() {
    local cmd="$1"
    [[ -z "$cmd" ]] && echo "" && return
    cmd="${cmd%% \;*}"
    cmd="${cmd%% \; *}"
    if [[ "$cmd" =~ ^send-prefix ]]; then echo "Send prefix"
    elif [[ "$cmd" =~ ^send-keys ]]; then echo "Send keys"
    elif [[ "$cmd" =~ select-pane[[:space:]]+-L ]]; then echo "Select pane left"
    elif [[ "$cmd" =~ select-pane[[:space:]]+-R ]]; then echo "Select pane right"
    elif [[ "$cmd" =~ select-pane[[:space:]]+-U ]]; then echo "Select pane up"
    elif [[ "$cmd" =~ select-pane[[:space:]]+-D ]]; then echo "Select pane down"
    elif [[ "$cmd" =~ kill-pane ]]; then echo "Kill pane"
    elif [[ "$cmd" =~ run-shell ]]; then echo "Run shell (sesh/snippet)"
    elif [[ "$cmd" =~ source-file ]]; then echo "Reload config"
    elif [[ "$cmd" =~ set-option[[:space:]]+status ]]; then echo "Toggle status"
    elif [[ "$cmd" =~ send[[:space:]]+-X[[:space:]]+copy-pipe ]]; then echo "Copy to clipboard"
    elif [[ "$cmd" =~ split-window ]]; then echo "Split window"
    elif [[ "$cmd" =~ new-window ]]; then echo "New window"
    elif [[ "$cmd" =~ kill-window ]]; then echo "Kill window"
    elif [[ "$cmd" =~ next-window ]]; then echo "Next window"
    elif [[ "$cmd" =~ previous-window ]]; then echo "Previous window"
    elif [[ "$cmd" =~ detach-client ]]; then echo "Detach"
    elif [[ "$cmd" =~ list-sessions ]]; then echo "List sessions"
    else
        echo "${cmd:0:40}"
    fi
}

# Parse tmux.conf for bind-key, bind, unbind-key, unbind
declare -A custom_binds
declare -A unbinds

if [[ -f "$CONFIG" ]]; then
    block=""
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        if [[ "$line" =~ ^[[:space:]]*(bind-key|bind|unbind-key|unbind)[[:space:]] ]]; then
            block="$line"
        elif [[ -n "$block" ]]; then
            block="$block $line"
        fi
        if [[ -z "$block" ]]; then continue; fi
        if [[ "$block" =~ ^[[:space:]]*unbind-key[[:space:]]+(-[^[:space:]]+[[:space:]]+)*([^[:space:]]+) ]]; then
            unbinds["${BASH_REMATCH[2]}"]=1
            block=""
            continue
        fi
        if [[ "$block" =~ ^[[:space:]]*unbind[[:space:]]+([^[:space:]]+) ]]; then
            unbinds["${BASH_REMATCH[1]}"]=1
            block=""
            continue
        fi
        # Bind: match only at start of block (avoid --bind inside run-shell)
        # Key must not start with - (avoid capturing -n or -T as key)
        if [[ "$block" =~ ^[[:space:]]*(bind-key|bind)[[:space:]]+(-n[[:space:]]+)?(-T[[:space:]]+[^[:space:]]+[[:space:]]+)?[\"\']?([^[:space:]\"\'-][^[:space:]\"\']*)[\"\']?[[:space:]]+(.*) ]]; then
            raw_key="${BASH_REMATCH[4]}"
            cmd="${BASH_REMATCH[5]}"
            [[ "$raw_key" =~ ctrl-|change-prompt|reload\(|execute\( ]] && block="" && continue
            cmd="${cmd%% bind-key *}"
            cmd="${cmd%% bind *}"
            if [[ "$block" =~ -T[[:space:]]+([^[:space:]]+)[[:space:]] ]]; then
                key="${BASH_REMATCH[1]} $raw_key"
            elif [[ "$block" =~ -n[[:space:]] ]]; then
                key="$raw_key"
            else
                key="Prefix $raw_key"
            fi
            [[ "$cmd" =~ run-shell ]] && cmd="run-shell"
            if [[ -n "$key" && -n "$cmd" ]]; then
                custom_binds["$key"]=$(cmd_to_desc "$cmd")
            fi
            block=""
        fi
        if [[ "$block" =~ \)\)[[:space:]]*$ ]] || [[ "$block" =~ \'[[:space:]]*$ ]]; then
            block=""
        fi
    done < "$CONFIG"
fi

# Start with default keybindings as the base
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

# Apply config: remove unbound, then overwrite/add from bind
for k in "${!unbinds[@]}"; do
    unset 'merged[$k]'
done
for k in "${!custom_binds[@]}"; do
    merged["$k"]="${custom_binds[$k]}"
done

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
