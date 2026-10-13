#!/bin/sh
# file-tree.sh open <window>   -> agent-state.sh on an agent edit: open the git
#                                 file tree on the right, unless closed by hand here.
# file-tree.sh toggle <window> -> prefix+F: close (and stop auto-open in this
#                                 window) or open and focus it.
# file-tree.sh resize <window> -> window-resized hook: keep it at WIDTH.
# The tree itself is file-tree.py; its pane is marked @filetree.
WIDTH=22%
dir=$(dirname "$(readlink -f "$0")")
tree="$dir/file-tree.py"
ft=$(tmux list-panes -t "$2" -F '#{pane_id} #{@filetree}' 2>/dev/null | awk '$2 == 1 {print $1}')

case $1 in
resize) [ -n "$ft" ] && tmux resize-pane -t "$ft" -x "$WIDTH" ;;
open)
	[ -z "$ft" ] && [ -z "$(tmux show -wqv -t "$2" @filetree_off)" ] && [ -z "$(tmux show -gqv @restoring)" ] &&
		new=$(tmux split-window -t "$2" -hfdP -F '#{pane_id}' -l "$WIDTH" "$tree") &&
		tmux set -p -t "$new" @filetree 1 # mark at once so a racing open sees it
	# A full-height split shrinks every column, the agent sidebar too: set it back.
	"$dir/agent-sidebar.sh" resize "$2"
	;;
toggle)
	if [ -n "$ft" ]; then
		tmux set -w -t "$2" @filetree_off 1 \; kill-pane -t "$ft"
	else
		tmux set -wu -t "$2" @filetree_off
		new=$(tmux split-window -t "$2" -hfP -F '#{pane_id}' -l "$WIDTH" "$tree") &&
			tmux set -p -t "$new" @filetree 1
		"$dir/agent-sidebar.sh" resize "$2"
	fi
	;;
esac
exit 0
