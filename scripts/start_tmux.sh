#!/usr/bin/env bash

SESSION="default"

if tmux has-session -t "$SESSION" 2>/dev/null; then
	exec tmux attach-session -t "$SESSION"
else
	exec tmux new-session -s "$SESSION"
fi
