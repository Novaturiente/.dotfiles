#!/bin/sh
# agent-state.sh <agent> <working|blocked|idle|off>
# Called by agent hooks. Stores state on the agent's own tmux pane as
# @agent (name) and @agent_state. idle on an unwatched pane after work = done.
[ -n "$TMUX_PANE" ] || exit 0
agent=$1 state=$2
p="-p -t $TMUX_PANE"

if [ "$state" = off ]; then
	tmux set $p -u @agent \; set $p -u @agent_state
	exit 0
fi

if [ "$state" = idle ]; then
	prev=$(tmux show $p -qv @agent_state)
	seen=$(tmux display -p -t "$TMUX_PANE" '#{&&:#{session_attached},#{&&:#{window_active},#{pane_active}}}')
	case $prev in
	working | blocked) [ "$seen" = 1 ] || state="done" ;;
	"done") state="done" ;;
	esac
fi

tmux set $p @agent "$agent" \; set $p @agent_state "$state"
