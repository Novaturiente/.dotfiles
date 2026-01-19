#!/usr/bin/env bash

# Split current tmux window horizontally
# Left pane: 65% width, opens neovim
# Right pane: 35% width, opens agent

# Split window horizontally, making right pane 35% (left becomes 65%)
tmux split-window -h -l 35%

# Open neovim in the left pane (pane 0)
tmux send-keys -t 0 "nvim" C-m

# Open agent in the right pane (pane 1)
tmux send-keys -t 1 "agent" C-m

# Switch focus back to left pane (neovim)
tmux select-pane -t 0
