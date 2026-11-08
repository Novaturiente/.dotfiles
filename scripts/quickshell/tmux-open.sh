#!/usr/bin/env bash
# Open a folder as a tmux session (Spotlight, Mod+D). If a terminal already runs
# tmux, switch its most recently used client to the session and focus that
# window; otherwise open a new ghostty window on it.
# Usage: tmux-open.sh <dir>
set -euo pipefail
DIR="${1:?usage: tmux-open.sh <dir>}"
# tmux names may not hold '.' or ':'; a session of the same name is reused.
NAME=$(basename "$DIR")
NAME=${NAME#.}
NAME=${NAME//[.: ]/-}
NAME=${NAME:-home}
WM=~/.dotfiles/scripts/wm.sh

tmux has-session -t "=$NAME" 2>/dev/null || tmux new-session -d -s "$NAME" -c "$DIR"

client=$(tmux list-clients -F '#{client_activity} #{client_name} #{client_pid}' 2>/dev/null | sort -rn | head -1)
if [[ -z $client ]]; then
    exec ghostty --title=tmux -e tmux attach -t "=$NAME"
fi
read -r _ cname cpid <<<"$client"
tmux switch-client -c "$cname" -t "=$NAME"

# Each ghostty window is its own process: focus the one the client runs under.
wins=$("$WM" windows)
pid=$cpid
while [[ $pid -gt 1 ]]; do
    id=$(jq -r --argjson p "$pid" 'first(.[] | select(.pid == $p) | .id) // empty' <<<"$wins")
    [[ -n $id ]] && exec "$WM" focus "$id"
    pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
done
