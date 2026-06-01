#!/usr/bin/env bash

# Toggle a two-pane side-by-side split between 30:70 and 70:30 by
# resizing the leftmost pane. Bound to a tmux key (see ~/.tmux.conf).
# Arg $1: target window id (passed by tmux as #{window_id}).

set -u

WIN="${1:-$(tmux display -p '#{window_id}')}"

# Leftmost pane (pane_left == 0) and its current width
read -r LID LWIDTH < <(
	tmux list-panes -t "$WIN" -F '#{pane_id} #{pane_left} #{pane_width}' \
		| awk '$2 == 0 { print $1, $3; exit }'
)
[[ -z "${LID:-}" ]] && exit 0

WWIDTH="$(tmux display -p -t "$WIN" '#{window_width}')"

# If the left pane is currently the narrow one (<50%), make it 70%;
# otherwise shrink it back to 30%.
if [[ "$LWIDTH" -lt $(( WWIDTH / 2 )) ]]; then
	tmux resize-pane -t "$LID" -x 70%
else
	tmux resize-pane -t "$LID" -x 30%
fi
