#!/usr/bin/env bash

# Split current tmux window horizontally
# Left pane: 65% width
# Right pane: 35% width, opens aider or agent based on argument

# Determine the command to run in the right pane
if [ "$1" = "-c" ]; then
    command="agent"
else
    command="aider"
fi

# Split window horizontally, making right pane 35% (left becomes 65%)
tmux split-window -h -l 35%

# Open the determined command in the right pane (pane 1)
tmux send-keys -t 1 "$command" C-m

# Switch focus back to left pane
tmux select-pane -t 0
