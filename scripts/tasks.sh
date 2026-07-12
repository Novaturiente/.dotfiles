#!/usr/bin/env bash
# Floating task scratchpad: normal nvim config + the tasks module.
exec ghostty --title=tasks-scratchpad -e nvim -c "lua require('tasks').open()"
