#!/bin/sh
# tmux-resurrect glue.
# resurrect.sh start <window> -> session-created hook: first session of a server
#   starts the 60s autosave loop and restores the last save; later ones just open a sidebar.
# resurrect.sh pre  -> resurrect pre-restore-all hook: drop sidebars, pause sidebar hooks.
# resurrect.sh post -> resurrect post-restore-all hook (and after start): drop the
#   restored sidebar shells, open a fresh sidebar in every window.
dir=$(dirname "$(readlink -f "$0")")
sidebar="$dir/agent-sidebar.sh"

case $1 in
start)
	[ -n "$(tmux show -gqv @restoring)" ] && exit 0
	if [ -n "$(tmux show -gqv @resurrect-started)" ]; then
		exec "$sidebar" open "$2"
	fi
	tmux set -g @resurrect-started 1
	save=$(tmux show -gqv @resurrect-save-script-path)
	restore=$(tmux show -gqv @resurrect-restore-script-path)
	# ponytail: fixed 60s poll; continuum not needed for one loop
	(while sleep 60 && tmux has-session 2>/dev/null; do "$save" quiet; done) >/dev/null 2>&1 &
	# No save file -> restore.sh exits without hooks, so run post ourselves.
	{ [ -n "$restore" ] && "$restore"; "$0" post; } >/dev/null 2>&1 &
	;;
pre)
	tmux set -g @restoring 1
	tmux list-panes -a -F '#{pane_id} #{@sidebar}' | awk '$2 == 1 {print $1}' |
		while read -r p; do tmux kill-pane -t "$p"; done
	;;
post)
	tmux set -gu @restoring
	# Saved sidebars come back as plain shells titled "agents".
	tmux list-panes -a -F '#{pane_id}	#{pane_title}	#{?#{@sidebar},s,p}' | awk -F'\t' '$2 == "agents" && $3 == "p" {print $1}' |
		while read -r p; do tmux kill-pane -t "$p"; done
	tmux list-windows -a -F '#{window_id}' | while read -r w; do "$sidebar" open "$w"; done
	;;
esac
