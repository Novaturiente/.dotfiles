#!/usr/bin/env bash
#
# Keybindings helper: rofi menu to pick a program, then show its keybindings.
# Keybindings are loaded from separate files in BINDINGS_DIR (one file per program).
#
# Rofi vs Zenity for showing keybindings:
#   Rofi: Same UX as program selector, keyboard-driven, consistent look.
#   Zenity: Scrollable text window, different (GTK) look.
# This script uses rofi for both steps for consistency.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINDINGS_DIR="${SCRIPT_DIR}/bindings"
ROFI_THEME="${ROFI_THEME:-black.rasi}"
ROFI_KEYBINDINGS_THEME="${SCRIPT_DIR}/keybindings.rasi"
MAX_KEYBINDING_LINES=28

# Discover programs from bindings dir (filename without .txt).
# Skip *-default.txt files (they are bases for merge, not menu entries).
get_programs() {
    if [[ ! -d "$BINDINGS_DIR" ]]; then
        return
    fi
    for f in "$BINDINGS_DIR"/*.txt; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f" .txt)
        [[ "$name" == *-default ]] && continue
        printf '%s\n' "$name"
    done | sort -V
}

get_keybindings() {
    local program="$1"
    local file="${BINDINGS_DIR}/${program}.txt"
    if [[ -f "$file" ]]; then
        cat "$file"
    else
        echo "No keybindings file for: $program"
    fi
}

copy_to_clipboard() {
    if command -v wl-copy &>/dev/null; then
        wl-copy
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard
    else
        true
    fi
}

main() {
    # Refresh keybindings from configs so they stay in sync
    "${SCRIPT_DIR}/extract-niri-keybindings.sh" "${NIRI_CONFIG:-$HOME/.config/niri/config.kdl}" >/dev/null 2>&1 || true
    "${SCRIPT_DIR}/extract-neovim-keybindings.sh" >/dev/null 2>&1 || true
    "${SCRIPT_DIR}/extract-qutebrowser-keybindings.sh" "${QUTEBROWSER_CONFIG:-$HOME/.config/qutebrowser_work/config/config.py}" >/dev/null 2>&1 || true
    "${SCRIPT_DIR}/extract-tmux-keybindings.sh" "${TMUX_CONFIG:-$HOME/.tmux.conf}" >/dev/null 2>&1 || true

    local programs
    programs=$(get_programs)
    if [[ -z "$programs" ]]; then
        rofi -e "No keybinding files in $BINDINGS_DIR" -theme "$ROFI_THEME"
        exit 1
    fi

    local chosen
    chosen=$(echo "$programs" | rofi -dmenu -i -p "Keybindings" -theme "$ROFI_THEME")
    [[ -z "$chosen" ]] && exit 0

    local bindings
    bindings=$(get_keybindings "$chosen")
    [[ -z "$bindings" ]] && exit 0

    local line_count
    line_count=$(echo "$bindings" | wc -l)
    [[ "$line_count" -gt "$MAX_KEYBINDING_LINES" ]] && line_count=$MAX_KEYBINDING_LINES

    local line
    line=$(echo "$bindings" | rofi -dmenu -i -p "$chosen keybindings (select to copy)" -theme "$ROFI_KEYBINDINGS_THEME" -lines "$line_count")
    if [[ -n "$line" ]]; then
        echo -n "$line" | copy_to_clipboard
    fi
}

main "$@"
