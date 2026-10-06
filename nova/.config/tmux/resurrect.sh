#!/bin/sh
# tmux-resurrect glue.
# resurrect.sh start <window> -> session-created hook: first session of a server
#   starts the 60s autosave loop and restores the last save; later ones just open a sidebar.
# resurrect.sh pre  -> resurrect pre-restore-all hook: drop sidebars, pause sidebar hooks.
# resurrect.sh post -> resurrect post-restore-all hook (and after start): drop the
#   restored sidebar shells, open a fresh sidebar in every window.
dir=$(dirname "$(readlink -f "$0")")
sidebar="$dir/agent-sidebar.sh"

case $1 in
start)
	[ -n "$(tmux show -gqv @restoring)" ] && exit 0
	if [ -n "$(tmux show -gqv @resurrect-started)" ]; then
		exec "$sidebar" open "$2"
	fi
	tmux set -g @resurrect-started 1
	save=$(tmux show -gqv @resurrect-save-script-path)
	restore=$(tmux show -gqv @resurrect-restore-script-path)
	# ponytail: fixed 60s poll; continuum not needed for one loop
	(while sleep 60 && tmux has-session 2>/dev/null; do "$save" quiet; done) >/dev/null 2>&1 &
	# No save file -> restore.sh exits without hooks, so run post ourselves.
	{ [ -n "$restore" ] && "$restore"; "$0" post; } >/dev/null 2>&1 &
	;;
pre)
	tmux set -g @restoring 1
	tmux list-panes -a -F '#{pane_id} #{@sidebar}' | awk '$2 == 1 {print $1}' |
		while read -r p; do tmux kill-pane -t "$p"; done
	;;
post)
	tmux set -gu @restoring
	# Saved sidebars come back as plain shells. Find them in the save file by their
	# saved title (live titles are unreliable: fish/zsh overwrite them after restore;
	# the saved command is empty because resurrect only records child processes).
	# Resolve all ids first, then kill, since killing shifts pane indices.
	# ponytail: assumes a from-scratch restore; a manual prefix+C-r over live panes may hit the wrong index
	rdir=$(tmux show -gqv @resurrect-dir)
	last=${rdir:-${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect}/last
	[ -f "$last" ] && awk -F'\t' '$1 == "pane" && $7 == "agents" {print $2 "\t" $3 "\t" $6}' "$last" |
		while IFS="$(printf '\t')" read -r s w i; do
			tmux display -p -t "=$s:$w.$i" '#{pane_id}' 2>/dev/null
		done | while read -r p; do tmux kill-pane -t "$p"; done
	tmux list-windows -a -F '#{window_id}' | while read -r w; do "$sidebar" open "$w"; done
	;;
save)
	# tmux.service ExecStop: save before the server and its agents are killed.
	s=$(tmux show -gqv @resurrect-save-script-path) && [ -n "$s" ] && "$s" quiet
	;;
map)
	# post-save-layout hook, $2 = save file. Agent panes that reported a conversation
	# (@agent_session) get their saved command replaced by `resurrect.sh resume <n>`;
	# agents.tsv maps n -> agent, conversation, original command. Numbered, not keyed
	# by pane position, because restore kills sidebar panes and shifts indices.
	rdir=$(tmux show -gqv @resurrect-dir)
	tsv=${rdir:-${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect}/agents.tsv
	live=$(mktemp)
	tmux list-panes -a -F '#{session_name}	#{window_index}	#{pane_index}	#{@agent}	#{@agent_session}' >"$live"
	: >"$tsv"
	awk -F'\t' -v OFS='\t' -v tsv="$tsv" -v cmd="$dir/resurrect.sh" '
		NR == FNR { if ($4 != "" && $5 != "") a[$1 FS $2 FS $3] = $4 FS $5; next }
		$1 == "pane" && (($2 FS $3 FS $6) in a) {
			n++; print n, a[$2 FS $3 FS $6], substr($11, 2) > tsv
			$11 = ":" cmd " resume " n
		}
		{ print }' "$live" "$2" >"$2.tmp" && mv "$2.tmp" "$2"
	rm -f "$live"
	;;
resume)
	# Sent into a restored pane by resurrect: reopen that pane's exact conversation.
	rdir=$(tmux show -gqv @resurrect-dir)
	tsv=${rdir:-${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect}/agents.tsv
	line=$(awk -F'\t' -v n="$2" '$1 == n' "$tsv")
	[ -n "$line" ] || exit 1
	tab=$(printf '\t')
	IFS=$tab read -r _ agent ref cmd <<EOF
$line
EOF
	# Record it now: agy only reports after its first prompt, and a save before
	# then would otherwise lose the conversation.
	tmux set -p -t "$TMUX_PANE" @agent "$agent" \; set -p -t "$TMUX_PANE" @agent_session "$ref"
	case $agent in
	pi) exec pi --session "$ref" ;;
	agy) exec agy --conversation "$ref" ;;
	codex) exec codex resume "$ref" ;;
	claude)
		# Keep flags like --dangerously-skip-permissions, drop old resume flags.
		# Drop everything up to the claude binary (may be preceded by an interpreter).
		set -- $cmd
		args= skip= seen=
		for a; do
			if [ -z "$seen" ]; then case $a in claude | */claude) seen=1 ;; esac; continue; fi
			if [ -n "$skip" ]; then skip=; continue; fi
			case $a in
			--continue | -c) ;;
			--resume | -r) skip=1 ;;
			*) args="$args $a" ;;
			esac
		done
		exec claude $args --resume "$ref"
		;;
	esac
	;;
esac
