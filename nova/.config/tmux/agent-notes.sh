#!/bin/bash
# Agent notes: a small popup at the top right listing agents outside the window you look at
# that finished (● done) or wait for you (✱ waiting), one line per agent: project and state.
# It stays until the notes clear (done: when you open that session, agent-sidebar.sh seen;
# waiting: when the agent moves on), on every session and tab.
#   agent-notes.sh show -> agent-state.sh (Claude Code/codex), novacode's hooks.onActivity
#                          (nova/.novacode/settings.json; novacode sets its pane state itself),
#                          session and tab switches: open the popup on every client with notes.
#                          tmux refuses a popup on a client already showing one, so it never
#                          replaces the scratch terminal or another popup.
#   agent-notes.sh draw <client> -> runs inside the popup. A popup takes all keyboard input, so
#                          it passes your typing through to the pane under it. A lone prefix key
#                          closes it and replays the prefix, so tmux bindings work; it reopens after.
#   agent-notes.sh next <client> -> prefix+Tab: jump to the first note's agent.
# Order (popup and prefix+Tab): waiting before done, then the oldest first.

# stamp: record when each agent's note began (pane options @note_state, @note_since); tmux keeps
# no time of option changes. Accurate to the next call: events, every second while the popup is
# open, and the 15s status-line retry.
stamp() {
	local p s ns
	while IFS='|' read -r p s ns; do
		if [[ $s == done || $s == blocked ]]; then
			[ "$s" = "$ns" ] || tmux set -p -t "$p" @note_state "$s" \; set -p -t "$p" @note_since "$EPOCHSECONDS"
		elif [ -n "$ns" ]; then
			tmux set -p -t "$p" -u @note_state \; set -p -t "$p" -u @note_since
		fi
	done < <(tmux list-panes -a -F '#{pane_id}|#{@agent_state}|#{@note_state}')
}

# queue <client>: notes for agents outside the client's current window, in order.
# Fields (tab): pane id, shown text.
queue() {
	local cw
	cw=$(tmux display -p -c "$1" '#{window_id}' 2>/dev/null) || return
	stamp
	tmux list-panes -a -F '#{pane_id}	#{window_id}	#{@agent_state}	#{@note_since}	#{?#{@agent_project},#{@agent_project},#{b:pane_current_path}}' |
		awk -F'\t' -v OFS='\t' -v cw="$cw" '
			$2 == cw { next }
			$3 == "blocked" { print 0, $4, $1, "\033[38;2;243;139;168m✱\033[0m " $5 "  \033[38;2;108;112;134mwaiting\033[0m" }
			$3 == "done" { print 1, $4, $1, "\033[38;2;166;227;161m●\033[0m " $5 "  \033[38;2;108;112;134mdone\033[0m" }' |
		sort -t$'\t' -k1,1n -k2,2n | cut -f3-
}

# notes <client>: the shown lines.
notes() { queue "$1" | cut -f2-; }

case $1 in
next)
	p=$(queue "$2" | head -1 | cut -f1)
	if [ -n "$p" ]; then
		tmux select-window -t "$p" \; select-pane -t "$p" \; switch-client -c "$2" -t "$p"
	else
		tmux display -c "$2" 'no agent notes'
	fi
	;;
show)
	shopt -s extglob
	tmux list-clients -F '#{client_name}' | while read -r c; do
		mapfile -t l < <(notes "$c")
		((${#l[@]})) || continue
		w=0
		for x in "${l[@]}"; do
			x=${x//$'\e['*([0-9;])m/}
			((${#x} > w)) && w=${#x}
		done
		# Size: text plus border and a space each side. Detached, so hooks never wait on it.
		tmux display-popup -c "$c" -x R -y S -w $((w + 4)) -h $((${#l[@]} + 2)) \
			-b rounded -S 'fg=#6c7086' -T ' agents ' -E "$0 draw '$c'" >/dev/null 2>&1 &
	done
	;;
draw)
	c=$2
	# Raw bytes: Enter stays \r and Ctrl-C reaches the pane instead of killing this script.
	stty raw -echo
	printf '\e[?25l'
	export LC_ALL=C
	n0=''
	while :; do
		mapfile -t l < <(notes "$c")
		((${#l[@]})) || exit 0
		# A note came or went: reopen at the new height.
		n0=${n0:-${#l[@]}}
		if [ "${#l[@]}" != "$n0" ]; then
			tmux run-shell -b "'$0' show"
			exit 0
		fi
		# Raw mode: lines need \r\n. $(...) drops the last \n, so a full popup never scrolls; the
		# last \r goes too, else the cursor is back at column 0 and \e[J erases that line.
		out=$(printf ' %s\e[K\r\n' "${l[@]}")
		printf '\e[H%s\e[J' "${out%$'\r'}"
		IFS= read -rsn1 -d '' -t1 k || continue
		printf -v h '%02x' "'$k"
		hex=("$h")
		# The rest of a burst (escape sequence, paste) goes over in one call.
		while IFS= read -rsn1 -d '' -t0.005 k; do
			printf -v h '%02x' "'$k"
			hex+=("$h")
		done
		# shortcut: prefixes hard-coded from tmux.conf (` and C-b), update both if they change.
		if [ ${#hex[@]} -eq 1 ] && [[ ${hex[0]} == 60 || ${hex[0]} == 02 ]]; then
			# Close first, so the replayed prefix and your next key reach tmux, not this popup.
			tmux run-shell -b "sleep 0.05; tmux send-keys -K -c '$c' $([ "${hex[0]}" = 60 ] && echo '\`' || echo C-b); sleep 1.5; '$0' show"
			exit 0
		fi
		tmux send-keys -t "$(tmux display -p -c "$c" '#{pane_id}')" -H "${hex[@]}"
	done
	;;
esac
