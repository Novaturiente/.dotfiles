#!/usr/bin/env bash

# lazygit edit/open handler. Opens the file in Neovim in a NEW tmux window
# (so lazygit stays visible in its pane). Falls back to the current terminal
# if not in tmux.
#
# Usage: lazygit-edit.sh <filename> [line]

set -u

file="${1:-}"
line="${2:-}"
[[ -z "$file" ]] && exit 0

args=()
[[ -n "$line" ]] && args+=("+$line")
args+=(-- "$file")

if [[ -n "${TMUX:-}" ]]; then
	# lazygit runs this from the repo root, so the relative filename resolves.
	tmux new-window -c "$PWD" -n "edit:$(basename "$file")" "exec nvim $(printf '%q ' "${args[@]}")"
else
	exec nvim "${args[@]}"
fi
