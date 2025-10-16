#!/bin/bash

SESSION_NAME="default"
TMUX_CONF="$HOME/.tmux.conf"
PLUGINS_DIR="$HOME/.tmux/plugins"

while true; do
	if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
		echo "[$(date)] Session $SESSION_NAME not found, recreating..."
		tmux new-session -d -s "$SESSION_NAME"
		# load_tmux_plugins &
	fi
	sleep 1
done
