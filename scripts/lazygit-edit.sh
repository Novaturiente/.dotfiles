#!/usr/bin/env bash

# lazygit edit/open handler. Opens the file in a terminal frame of the Emacs
# daemon, in a NEW tmux window (so lazygit stays visible in its pane). Falls
# back to the current terminal if not in tmux.
#
# Usage: lazygit-edit.sh <filename> [line]

set -u

file="${1:-}"
line="${2:-}"
[[ -z "$file" ]] && exit 0

# lazygit runs this from the repo root; keep that as the working dir so the
# (relative) filename resolves.
workdir="$PWD"

# Build the emacsclient command safely (handles spaces in paths)
qfile="$(printf '%q' "$file")"
ecmd="exec emacsclient -t --alternate-editor="
[[ -n "$line" ]] && ecmd="$ecmd +$line"
ecmd="$ecmd -- $qfile"

if [[ -n "${TMUX:-}" ]]; then
	tmux new-window -c "$workdir" -n "edit:$(basename "$file")" "$ecmd"
else
	if [[ -n "$line" ]]; then
		exec emacsclient -t --alternate-editor= +"$line" -- "$file"
	else
		exec emacsclient -t --alternate-editor= -- "$file"
	fi
fi
