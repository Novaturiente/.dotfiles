#!/usr/bin/env bash

# Toggle the LEFT pane of the current window between lazygit and explorenova.
# Bound to a tmux key. Default cproj shows lazygit; this swaps and back.

set -u

WIN="$(tmux display -p '#{window_id}')"
SESS="$(tmux display -p '#{session_name}')"

# Leftmost pane (pane_left == 0) and what it is running
read -r LID LCMD < <(
	tmux list-panes -t "$WIN" -F '#{pane_id} #{pane_left} #{pane_current_command}' \
		| awk '$2 == 0 { print $1, $3; exit }'
)
[[ -z "${LID:-}" ]] && exit 0

# Project dir: prefer the value cproj stored on the session
DIR="$(tmux show-options -v -t "$SESS" @cproj_dir 2>/dev/null || true)"
[[ -z "$DIR" || ! -d "$DIR" ]] && DIR="$(tmux display -p -t "$LID" '#{pane_current_path}')"

LAZYGIT_BIN="$(command -v lazygit || echo /usr/bin/lazygit)"
EXPLORENOVA_BIN="$(command -v explorenova || echo /usr/sbin/explorenova)"

case "$LCMD" in
explorenova)
	# explorenova -> back to lazygit (keep CPROJ for nvim inline diff)
	tmux respawn-pane -k -t "$LID" -c "$DIR" "CPROJ=1 $LAZYGIT_BIN"
	;;
*)
	# lazygit (or anything else) -> explorenova
	tmux respawn-pane -k -t "$LID" -c "$DIR" "$EXPLORENOVA_BIN --tree-only"
	;;
esac

# Focus the (left) pane that was just swapped
tmux select-pane -t "$LID"
