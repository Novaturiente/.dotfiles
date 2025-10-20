#!/bin/bash

SESSION="default"

if tmux has-session -t $SESSION 2>/dev/null; then
	# Session exists → attach
	tmux attach -t $SESSION
else
	# Create new session and run rtorrent inside it
	tmux new-session -s $SESSION
fi
