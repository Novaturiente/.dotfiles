#!/usr/bin/env bash

if [ $# -eq 0 ]; then
	ghostty -e "cd ~/gemini && /usr/bin/gemini"
else
	for arg in "$@"; do
		if [ "$arg" == "-w" ]; then
			echo "Launching in workspace"
			ghostty -e "zsh -ic 'selected_dir=\$(fd --type d --max-depth 2 | fzf); [ -n \"\$selected_dir\" ] && cd \"\$selected_dir\" || cd ~/gemini; gemini'"
		else
			echo "Invalida Argument"
		fi
	done
fi
