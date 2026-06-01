#!/usr/bin/env bash

# Project picker: rofi -> select a project dir -> open ghostty attached to a
# tmux session with lazygit (30%) on the left and claude (70%) on the right.
# Tmux keeps the session alive between launches.

PROJECT_ROOTS=(
	"$HOME/.dotfiles"
	"$HOME/Projects"
	"$HOME/projects"
	"$HOME/personal"
	"$HOME/work"
	"$HOME/Notes"
)

FOLDER_ICON="󰙅"

ENTRIES=""
for root in "${PROJECT_ROOTS[@]}"; do
	[[ -d "$root" ]] || continue
	ENTRIES+="${FOLDER_ICON} ${root}"$'\n'
	while IFS= read -r d; do
		ENTRIES+="${FOLDER_ICON} ${d}"$'\n'
	done < <(fd --type d --max-depth 1 --hidden --exclude '.git' . "$root" 2>/dev/null)
done

ENTRIES="${ENTRIES%$'\n'}"

SELECTED=$(echo "$ENTRIES" | awk '!seen[$0]++' | rofi -dmenu -i -p "󱉶 PROJECT" -theme "black.rasi")

[[ -z "$SELECTED" ]] && exit 0

SELECTED="${SELECTED:2}"
[[ -d "$SELECTED" ]] || exit 1

# Safe tmux session name from the folder basename
SESSION_NAME="$(basename "$SELECTED")"
SESSION_NAME="${SESSION_NAME#.}"
SESSION_NAME="${SESSION_NAME//:/-}"
SESSION_NAME="${SESSION_NAME//./-}"
SESSION_NAME="${SESSION_NAME// /_}"

# Make sure the tmux server has ~/.local/bin etc. on PATH so claude resolves
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.npm-global/bin:$HOME/go/bin:$PATH"
tmux set-environment -g PATH "$PATH" 2>/dev/null || true

LAZYGIT_BIN="$(command -v lazygit || echo /usr/bin/lazygit)"
CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"
CLAUDE_CMD="$CLAUDE_BIN --dangerously-skip-permissions"

needs_rebuild=1
if tmux has-session -t="$SESSION_NAME" 2>/dev/null; then
	pane_count=$(tmux list-panes -t "$SESSION_NAME" 2>/dev/null | wc -l)
	if [[ "$pane_count" -ge 2 ]]; then
		needs_rebuild=0
	else
		# Broken / single-pane leftover — wipe and rebuild
		tmux kill-session -t "$SESSION_NAME" 2>/dev/null
	fi
fi

if [[ "$needs_rebuild" -eq 1 ]]; then
	# Pane 0 (left, 25%): lazygit
	tmux new-session -d -s "$SESSION_NAME" -x 200 -y 50 -c "$SELECTED" "$LAZYGIT_BIN"
	# Pane 1 (right, 75%): claude
	tmux split-window -h -l 70% -t "$SESSION_NAME" -c "$SELECTED" "$CLAUDE_CMD"
	tmux select-pane -t "$SESSION_NAME" -R
fi

exec ghostty -e tmux attach-session -t "$SESSION_NAME"
