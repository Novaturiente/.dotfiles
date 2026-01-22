#!/usr/bin/env bash

# Split current tmux window horizontally
# Left pane: 65% width
# Right pane: 35% width, opens agent

# Split window horizontally, making right pane 35% (left becomes 65%)
tmux split-window -h -l 35%

# Open agent in the right pane (pane 1)
tmux send-keys -t 1 "agent" C-m

# Switch focus back to left pane
tmux select-pane -t 0
