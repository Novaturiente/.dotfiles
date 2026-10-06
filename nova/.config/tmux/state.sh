#!/bin/sh
# Event-driven tmux persistence (replaces tmux-resurrect). One JSON file holds
# sessions -> windows -> panes (folder, branch, agent + conversation), rewritten
# whenever something changes. No timer.
#   state.sh save   -> any trigger: tmux hooks, agent-state.sh, shell cd hooks.
#                      Returns at once; triggers within 0.5s become one write.
#   state.sh flush  -> write now (tmux.service ExecStop).
#   state.sh start <window> -> session-created hook. The first session of a server
#                      restores the file; later ones open a sidebar and save.
# File: ${TMUX_STATE_DIR:-~/.local/share/tmux}/state.json, previous copy in state.json.bak.
dir=$(dirname "$(readlink -f "$0")")
self="$dir/state.sh"
sidebar="$dir/agent-sidebar.sh"
sdir=${TMUX_STATE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/tmux}
file="$sdir/state.json"
tab=$(printf '\t')
nl='
'
mkdir -p "$sdir"

flush() {
	# Only a server whose state we restored may overwrite the file.
	[ -n "$(tmux show -gqv @state-started 2>/dev/null)" ] || return 0
	[ -n "$(tmux show -gqv @restoring)" ] && return 0
	f="#{pane_pid}$tab#{pane_current_path}$tab#{session_name}$tab#{window_index}$tab#{window_name}$tab#{window_active}$tab#{window_layout}$tab#{automatic-rename}$tab#{pane_index}$tab#{pane_active}$tab#{pane_current_command}$tab#{@sidebar}$tab#{@agent}$tab#{@agent_session}$tab#{@agent_cwd}"
	# Fails with zero sessions too. Server still answering = everything closed by
	# hand: save an empty state. Server gone (shutdown) = keep the file.
	if ! panes=$(tmux list-panes -a -F "$f" 2>/dev/null); then
		[ -n "$(tmux show -gqv @state-started 2>/dev/null)" ] || return 0
		panes=''
	fi
	tmp="$file.$$"
	# Per pane add: git branch, full command of the foreground program.
	if printf '%s\n' "$panes" | while IFS= read -r l; do
		[ -n "$l" ] || continue
		pid=${l%%"$tab"*} rest=${l#*"$tab"}
		path=${rest%%"$tab"*}
		fg=$(ps -o tpgid= -p "$pid" | tr -d ' ')
		args=$(ps -o args= -p "$fg" 2>/dev/null)
		branch=$(git -C "$path" branch --show-current 2>/dev/null)
		printf '%s\t%s\t%s\n' "$l" "$branch" "$args"
	done | jq -R -s --arg t "$(date -Iseconds)" '
		def nz: if . == "" then null else . end;
		# Reported via hook (@agent), or a known agent that has not reported yet.
		# Foreground back to a shell = the agent exited.
		def agent:
			(if .[12] != "" then .[12] elif (.[10] | test("^(agy|claude|pi|codex)$")) then .[10] else "" end) as $n
			| if $n == "" or (.[10] | test("^(zsh|bash|fish|sh)$")) then null
			  else {name: $n, conversation: (.[13] | nz), cwd: (.[14] | nz), command: (.[16] | nz)} end;
		[split("\n")[] | select(length > 0) | split("\t")]
		| {saved: $t, sessions: [group_by(.[2])[] | {name: .[0][2], windows: [group_by(.[3] | tonumber)[] | {
			index: (.[0][3] | tonumber), name: .[0][4], auto_name: (.[0][7] == "1"),
			active: (.[0][5] == "1"), layout: .[0][6],
			panes: [sort_by(.[8] | tonumber)[] | {
				index: (.[8] | tonumber), active: (.[9] == "1"), cwd: .[1], branch: (.[15] | nz),
				sidebar: (.[11] == "1"), agent: agent}]}]}]}' >"$tmp"; then
		[ -f "$file" ] && cp "$file" "$file.bak"
		mv "$tmp" "$file" # atomic: a crash never leaves a half-written file
	else
		rm -f "$tmp"
	fi
}

save() {
	[ -n "$(tmux show -gqv @restoring 2>/dev/null)" ] && return 0
	: >"$sdir/.dirty"
	(
		exec 9>"$sdir/.lock"
		flock -n 9 || exit 0 # a writer is already waiting; it will see .dirty
		while [ -f "$sdir/.dirty" ]; do
			sleep 0.5
			rm -f "$sdir/.dirty"
			flush
		done
		exec 9>&-
		# A trigger that landed after the last check, while the lock was still held.
		[ ! -f "$sdir/.dirty" ] || exec "$self" save
	) >/dev/null 2>&1 </dev/null &
}

claude_flags() {
	# Keep flags like --dangerously-skip-permissions; drop old resume flags and
	# everything up to the claude binary (may be preceded by an interpreter).
	out='' skip='' seen=''
	for a in $1; do
		if [ -z "$seen" ]; then case $a in claude | */claude) seen=1 ;; esac; continue; fi
		if [ -n "$skip" ]; then skip=''; continue; fi
		case $a in
		--continue | -c) ;;
		--resume | -r) skip=1 ;;
		*) out="$out $a" ;;
		esac
	done
	printf '%s' "$out"
}

# resume_cmd <agent> <conversation or ''> <saved command>: exact conversation,
# else the latest one in the folder.
resume_cmd() {
	case $1 in
	pi) if [ -n "$2" ]; then echo "pi --session '$2'"; else echo "pi -c"; fi ;;
	agy) if [ -n "$2" ]; then echo "agy --conversation '$2'"; else echo "agy -c"; fi ;;
	codex) if [ -n "$2" ]; then echo "codex resume '$2'"; else echo "codex resume --last"; fi ;;
	claude)
		fl=$(claude_flags "$3")
		if [ -n "$2" ]; then echo "claude$fl --resume '$2'"; else echo "claude$fl --continue"; fi
		;;
	esac
}

# After all panes of window $cw exist: saved layout, then each pane's role.
# Roles come last so a lone sidebar pane never triggers the reap hook.
finish() {
	[ -n "$cw" ] || return 0
	tmux select-layout -t "$cw" "$clay" 2>/dev/null
	# f_* names: restore's loop has already read the next row into p/sb/an/... .
	while IFS=$tab read -r f_p f_sb f_an f_ac f_cmd f_miss; do
		[ -n "$f_p" ] || continue
		if [ "$f_sb" = 1 ]; then
			tmux respawn-pane -k -t "$f_p" "$sidebar" \; set -p -t "$f_p" @sidebar 1
			continue
		fi
		[ "$f_miss" = - ] || tmux send-keys -t "$f_p" -l "echo 'restore: $f_miss no longer exists, opened its nearest parent'" \; send-keys -t "$f_p" Enter
		[ "$f_an" = - ] && continue
		[ "$f_ac" = - ] && f_ac=''
		tmux set -p -t "$f_p" @agent "$f_an"
		[ -n "$f_ac" ] && tmux set -p -t "$f_p" @agent_session "$f_ac"
		tmux send-keys -t "$f_p" -l "$(resume_cmd "$f_an" "$f_ac" "$f_cmd")" \; send-keys -t "$f_p" Enter
	done <<EOF
$roles
EOF
	[ -n "$cact" ] && tmux select-pane -t "$cact"
	[ "$cauto" = 1 ] || tmux rename-window -t "$cw" "$cwn"
}

restore() {
	is=$(tmux display -p -t "$1" '#{session_id}')
	rows=''
	# One line per pane; "-" for empty so tab-splitting keeps the columns.
	[ -s "$file" ] && rows=$(jq -r '.sessions[] as $s | $s.windows[] as $w | $w.panes[] | [
		$s.name, ($w.index | tostring), (if $w.name == "" then "-" else $w.name end),
		(if $w.auto_name then "1" else "0" end), $w.layout, (if $w.active then "1" else "0" end),
		(if .active then "1" else "0" end), .cwd, (if .sidebar then "1" else "0" end),
		(.agent.name // "-"), (.agent.conversation // "-"), (.agent.command // "-")] | join("\t")' "$file" 2>/dev/null)
	if [ -n "$rows" ]; then
		# Starting session out of the way (saved names may include "0"); dropped after.
		tmux rename-session -t "$is" "restoring-$$"
		cur='' cs='' cw='' acts=''
		while IFS=$tab read -r s wi wn wauto lay wact pact cwd sb an ac acmd; do
			# Deleted folder (e.g. removed worktree): nearest parent that exists.
			d=$cwd
			while [ ! -d "$d" ]; do d=$(dirname "$d"); done
			miss=-
			[ "$d" = "$cwd" ] || miss=$cwd
			if [ "$s:$wi" != "$cur" ]; then
				finish
				cur="$s:$wi" roles='' cact='' clay=$lay cauto=$wauto cwn=$wn
				if [ "$s" != "$cs" ]; then
					wh=$(printf '%s' "$lay" | sed -E 's/^[^,]*,([0-9]+)x([0-9]+),.*/\1 \2/')
					cw=$(tmux new-session -d -P -F '#{window_id}' -s "$s" -c "$d" -x "${wh% *}" -y "${wh#* }")
					cs=$s
				else
					cw=$(tmux new-window -d -P -F '#{window_id}' -t "=$s:" -c "$d")
				fi
				p=$(tmux display -p -t "$cw" '#{pane_id}')
				[ "$wact" = 1 ] && acts="$acts $cw"
			else
				# Split the last pane so pane order matches the saved layout.
				np=$(tmux split-window -d -P -F '#{pane_id}' -t "$p" -c "$d") || continue
				p=$np
				tmux select-layout -t "$cw" tiled
			fi
			[ "$pact" = 1 ] && cact=$p
			roles="$roles$p$tab$sb$tab$an$tab$ac$tab$acmd$tab$miss$nl"
		done <<EOF
$rows
EOF
		finish
		for w in $acts; do tmux select-window -t "$w"; done
		tmux kill-session -t "$is"
	fi
	tmux set -gu @restoring
	tmux list-windows -a -F '#{window_id}' | while read -r w; do "$sidebar" open "$w"; done
	flush
}

case $1 in
save) save ;;
flush) flush ;;
start)
	if [ -n "$(tmux show -gqv @state-started)" ]; then
		[ -n "$(tmux show -gqv @restoring)" ] && exit 0
		"$sidebar" open "$2"
		save
	else
		# Both flags at once, so no save can overwrite the file before restore reads it.
		tmux set -g @state-started 1 \; set -g @restoring 1
		restore "$2" >/dev/null 2>&1 </dev/null &
	fi
	;;
esac
