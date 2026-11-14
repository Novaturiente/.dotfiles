#!/bin/bash
# Agent notes: a small floating pane at the top right of the window you look at, listing agents
# in other windows that finished (● done) or wait for you (✱ waiting): project and state.
# A floating pane (tmux 3.8 new-pane -d) never takes focus, so typing and the mouse work as
# usual. It stays until the notes clear (done: when you open that session, agent-sidebar.sh
# seen; waiting: when the agent moves on), on every session and tab.
#   agent-notes.sh show -> agent-state.sh (Claude Code/codex), novacode's hooks.onActivity
#                          (nova/.novacode/settings.json; novacode sets its pane state itself),
#                          session/tab switches, window resizes and a status-line retry: put the
#                          note pane in every window a client looks at, remove the others.
#   agent-notes.sh draw <window> -> runs in the note pane; a click on it jumps like prefix+Tab.
#   agent-notes.sh next <client> -> prefix+Tab: jump to the first note's agent.
# Order (note pane and prefix+Tab): waiting before done, then the oldest first.
# The pane is marked @sidebar=notes (panel code skips it) and @slot=notes (state.sh never saves it).

# stamp: record when each agent's note began (pane options @note_state, @note_since); tmux keeps
# no time of option changes. Accurate to the next call: events, every second in a note pane,
# and the 15s status-line retry.
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

# queue <window>: notes for agents outside that window, in order. Fields (tab): pane id, text.
queue() {
	stamp
	tmux list-panes -a -F '#{pane_id}	#{window_id}	#{@agent_state}	#{@note_since}	#{?#{@agent_project},#{@agent_project},#{b:pane_current_path}}' |
		awk -F'\t' -v OFS='\t' -v cw="$1" '
			$2 == cw { next }
			$3 == "blocked" { print 0, $4, $1, "\033[38;2;243;139;168m✱\033[0m " $5 "  \033[38;2;108;112;134mwaiting\033[0m" }
			$3 == "done" { print 1, $4, $1, "\033[38;2;166;227;161m●\033[0m " $5 "  \033[38;2;108;112;134mdone\033[0m" }' |
		sort -t$'\t' -k1,1n -k2,2n | cut -f3-
}

# notes <window>: the shown lines.
notes() { queue "$1" | cut -f2-; }

# jump <window>: go to the first note's agent, for the client looking at <window>.
jump() {
	local p c
	p=$(queue "$1" | head -1 | cut -f1)
	c=$(tmux list-clients -F '#{window_id} #{client_name}' | awk -v w="$1" '$1 == w {print $2; exit}')
	[ -n "$p" ] && [ -n "$c" ] && tmux select-window -t "$p" \; select-pane -t "$p" \; switch-client -c "$c" -t "$p"
}

case $1 in
next)
	w=$(tmux display -p -c "$2" '#{window_id}')
	[ -n "$(queue "$w")" ] && jump "$w" || tmux display -c "$2" 'no agent notes'
	;;
show)
	shopt -s extglob
	exec 9>"${XDG_RUNTIME_DIR:-/tmp}/tmux-agent-notes.lock" && flock 9
	mapfile -t seen < <(tmux list-clients -F '#{window_id}' | sort -u)
	# Note panes in windows nobody looks at: gone.
	tmux list-panes -a -F '#{pane_id} #{window_id} #{@sidebar}' | while read -r p w k; do
		[ "$k" = notes ] && [[ " ${seen[*]} " != *" $w "* ]] && tmux kill-pane -t "$p"
	done
	for w in "${seen[@]}"; do
		mapfile -t l < <(notes "$w")
		old=$(tmux list-panes -t "$w" -F '#{pane_id} #{@sidebar} #{@note_geom}' | awk '$2 == "notes"')
		if ((${#l[@]} == 0)); then
			[ -n "$old" ] && tmux kill-pane -t "${old%% *}"
			continue
		fi
		tw=0
		for x in "${l[@]}"; do
			x=${x//$'\e['*([0-9;])m/}
			((${#x} > tw)) && tw=${#x}
		done
		# Size: text plus a space each side and the border; one column from the window's right edge.
		pw=$((tw + 4)) ph=$((${#l[@]} + 2)) ww=$(tmux display -p -t "$w" '#{window_width}')
		geom="$pw,$ph,$ww"
		[ "${old##* }" = "$geom" ] && continue
		[ -n "$old" ] && tmux kill-pane -t "${old%% *}"
		new=$(tmux new-pane -d -P -F '#{pane_id}' -t "$w" -x "$pw" -y "$ph" -X $((ww - pw - 1)) -Y 0 \
			-B single -R 'fg=#6c7086' -S 'fg=#6c7086' -T ' agents ' "'$0' draw '$w'") &&
			tmux set -p -t "$new" @sidebar notes \; set -p -t "$new" @slot notes \; set -p -t "$new" @note_geom "$geom"
	done
	;;
draw)
	# Hide the cursor; SGR mouse reporting so a click reaches the read below.
	printf '\e[?25l\e[?1000h\e[?1006h'
	n0=''
	while :; do
		mapfile -t l < <(notes "$2")
		((${#l[@]})) || exit 0
		# A note came or went: show rebuilds the pane at the new size.
		n0=${n0:-${#l[@]}}
		[ "${#l[@]}" = "$n0" ] || { tmux run-shell -b "'$0' show"; exit 0; }
		# $(...) drops the last newline, so a full pane never scrolls.
		printf '\e[H%s\e[J' "$(printf ' %s\e[K\n' "${l[@]}")"
		# Any input here is a click (focus only comes by mouse): jump, then hand focus back.
		if read -rsn1 -t1 _; then
			while read -rsn1 -t0.05 _; do :; done
			tmux last-pane -t "$TMUX_PANE" 2>/dev/null
			jump "$2"
		fi
	done
	;;
esac
