#!/usr/bin/env bash

# lazygit edit/open handler. Opens the file in nvim in a NEW tmux window
# (so lazygit stays visible in its pane), with CPROJ=1 so nvim auto-enables
# the whole-file inline git diff. Falls back to a plain nvim if not in tmux.
#
# Usage: lazygit-edit.sh <filename> [line]

set -u

file="${1:-}"
line="${2:-}"
[[ -z "$file" ]] && exit 0

# lazygit runs this from the repo root; keep that as the working dir so the
# (relative) filename resolves.
workdir="$PWD"

# Build the nvim command safely (handles spaces in paths)
qfile="$(printf '%q' "$file")"
ncmd="CPROJ=1 exec nvim"
[[ -n "$line" ]] && ncmd="$ncmd +$line"
ncmd="$ncmd -- $qfile"

if [[ -n "${TMUX:-}" ]]; then
	tmux new-window -c "$workdir" -n "edit:$(basename "$file")" "$ncmd"
else
	if [[ -n "$line" ]]; then
		exec nvim +"$line" -- "$file"
	else
		exec nvim -- "$file"
	fi
fi
