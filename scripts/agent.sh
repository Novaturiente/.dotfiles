#!/usr/bin/env zsh

# pull in the user’s interactive environment once
source ~/.zshrc

# now proceed exactly as before
question=$(rofi -show -dmenu -theme spotlight -p "Question")
(( $? == 0 )) || exit

ghostty --title="aiassistant" \
        --working-directory="$HOME/Code/develop/kimi" \
        -e "uv run main.py '$question'"
