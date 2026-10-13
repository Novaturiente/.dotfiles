#!/bin/sh
# agent-state.sh <agent> <working|blocked|idle|off|-> [ref|-] [cwd] [edited file]
# Called by agent hooks. Stores state on the agent's own tmux pane as
# @agent (name) and @agent_state. idle on an unwatched pane after work = done.
# state "-" keeps the current state (e.g. Claude's CwdChanged hook).
# ref = conversation id/file, stored as @agent_session for exact resume after a
# restore; "-" reads it, and the folder, from the hook's JSON on stdin
# (session_id / conversationId, new_cwd / cwd). cwd is stored as @agent_cwd.
# @agent_project = git repo (main checkout name, so worktrees map back) of the
# last edited file, or of the folder after a folder change; a folder outside any
# repo clears it. The sidebar shows it on the session row.
# An edit opens the git file tree in the agent's window (file-tree.sh open).
# A change of agent, conversation or folder saves tmux state (state.sh save).
# Entering done or blocked on an unwatched pane sends a desktop notification
# (OSC 777) to every attached client's terminal, so it reaches the laptop over SSH.
[ -n "$TMUX_PANE" ] || exit 0
agent=$1 state=$2 ref=$3 cwd=$4 file=$5
p="-p -t $TMUX_PANE"
dir=$(dirname "$(readlink -f "$0")")
save="$dir/state.sh"

if [ "$state" = off ]; then
	tmux set $p -u @agent \; set $p -u @agent_state \; set $p -u @agent_session \; set $p -u @agent_cwd \; set $p -u @agent_project
	"$save" save
	exit 0
fi

if [ "$ref" = - ]; then
	j=$(cat)
	ref=$(printf '%s' "$j" | jq -r '.session_id // .conversationId // empty' 2>/dev/null)
	cwd=$(printf '%s' "$j" | jq -r '.new_cwd // .cwd // empty' 2>/dev/null)
	file=$(printf '%s' "$j" | jq -r 'select(.tool_name | test("^(Edit|MultiEdit|Write|NotebookEdit)$")?) | .tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)
fi

# Repo name for a folder; empty outside git.
project() {
	r=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && basename "$(dirname "$r")"
}

tab=$(printf '\t')
old=$(tmux display -p -t "$TMUX_PANE" "#{@agent}$tab#{@agent_session}$tab#{@agent_cwd}")
[ -n "$ref" ] && tmux set $p @agent_session "$ref"
[ -n "$cwd" ] && tmux set $p @agent_cwd "$cwd"
# Edit outside any repo (/tmp, ~/.claude) leaves the project as it was.
if [ -n "$file" ] && pr=$(project "$(dirname "$file")") && [ -n "$pr" ]; then
	tmux set $p @agent_project "$pr"
elif [ -n "$cwd" ] && [ "$cwd" != "${old##*"$tab"}" ]; then
	if pr=$(project "$cwd") && [ -n "$pr" ]; then tmux set $p @agent_project "$pr"; else tmux set $p -u @agent_project; fi
fi

[ -n "$file" ] && "$dir/file-tree.sh" open "$(tmux display -p -t "$TMUX_PANE" '#{window_id}')"

prev=$(tmux show $p -qv @agent_state)
[ "$state" = - ] && state=${prev:-idle}
seen=$(tmux display -p -t "$TMUX_PANE" '#{&&:#{session_attached},#{&&:#{window_active},#{pane_active}}}')
if [ "$state" = idle ]; then
	case $prev in
	working | blocked) [ "$seen" = 1 ] || state="done" ;;
	"done") state="done" ;;
	esac
fi

tmux set $p @agent "$agent" \; set $p @agent_state "$state"

new=$(tmux display -p -t "$TMUX_PANE" "#{@agent}$tab#{@agent_session}$tab#{@agent_cwd}")
[ "$new" = "$old" ] || "$save" save

if [ "$state" != "$prev" ] && [ "$seen" != 1 ]; then
	case $state in
	"done" | blocked)
		where=$(tmux display -p -t "$TMUX_PANE" '#{session_name}:#{window_index} #{b:pane_current_path}')
		# ponytail: raw write to client ttys; a byte race with tmux redraw is possible but harmless
		tmux list-clients -F '#{client_tty}' | while read -r t; do
			printf '\033]777;notify;%s %s;%s\033\\' "$agent" "$state" "$where" >"$t" 2>/dev/null
		done
		;;
	esac
fi
