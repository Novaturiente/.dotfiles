#!/bin/sh
# agent-state.sh <agent> <working|blocked|idle|off|-> [ref|-] [cwd]
# Called by agent hooks. Stores state on the agent's own tmux pane as
# @agent (name) and @agent_state. idle on an unwatched pane after work = done.
# state "-" keeps the current state (e.g. Claude's CwdChanged hook).
# ref = conversation id/file, stored as @agent_session for exact resume after a
# restore; "-" reads it, and the folder, from the hook's JSON on stdin
# (session_id / conversationId, new_cwd / cwd). cwd is stored as @agent_cwd.
# A change of agent, conversation or folder saves tmux state (state.sh save).
# Entering done or blocked on an unwatched pane sends a desktop notification
# (OSC 777) to every attached client's terminal, so it reaches the laptop over SSH.
[ -n "$TMUX_PANE" ] || exit 0
agent=$1 state=$2 ref=$3 cwd=$4
p="-p -t $TMUX_PANE"
save="$(dirname "$(readlink -f "$0")")/state.sh"

if [ "$state" = off ]; then
	tmux set $p -u @agent \; set $p -u @agent_state \; set $p -u @agent_session \; set $p -u @agent_cwd
	"$save" save
	exit 0
fi

if [ "$ref" = - ]; then
	j=$(cat)
	ref=$(printf '%s' "$j" | jq -r '.session_id // .conversationId // empty' 2>/dev/null)
	cwd=$(printf '%s' "$j" | jq -r '.new_cwd // .cwd // empty' 2>/dev/null)
fi

tab=$(printf '\t')
old=$(tmux display -p -t "$TMUX_PANE" "#{@agent}$tab#{@agent_session}$tab#{@agent_cwd}")
[ -n "$ref" ] && tmux set $p @agent_session "$ref"
[ -n "$cwd" ] && tmux set $p @agent_cwd "$cwd"

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
