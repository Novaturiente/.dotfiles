#!/usr/bin/env bash
# Open a terminal (titled EDITOR) at ~/.dotfiles, fuzzy-search files with
# `tv files` (television), and open the selection in neovim.

exec ghostty \
	--class=EDITOR \
	--title=EDITOR \
	--working-directory="$HOME/.dotfiles" \
	-e bash -c 'file=$(tv files --source-command "fd -t f --hidden") && [ -n "$file" ] && exec nvim "$file"'
