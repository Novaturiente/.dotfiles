#!/bin/bash
# Ensure environment is sane
export TERM=xterm-256color

# Optional: sleep to let Ghostty settle (can fix render glitches)
sleep 0.1

# Run ranger with passed args
exec ghostty -l --title="filepick" -e ranger "$@"
