#!/bin/bash
# agent-sidebar.sh toggle  -> prefix+A: open/close the sidebar in this window.
# agent-sidebar.sh         -> draw loop, runs inside the sidebar pane.
# Keys in the sidebar: 1-9 jump to that agent, q closes.
if [ "$1" = toggle ]; then
	sb=$(tmux list-panes -t "$2" -F '#{pane_id} #{@sidebar}' | awk '$2 == 1 {print $1}')
	if [ -n "$sb" ]; then
		tmux kill-pane -t "$sb"
	else
		tmux split-window -t "$2" -hbfd -l 17 "$0"
	fi
	exit
fi

tmux set -p -t "$TMUX_PANE" @sidebar 1 \; select-pane -t "$TMUX_PANE" -T agents
printf '\e[?25l'
trap 'printf "\e[?25h"' EXIT

# Catppuccin Mocha: yellow, red, green, overlay0
declare -A col=([working]='249;226;175' [blocked]='243;139;168' [done]='166;227;161' [idle]='108;112;134')
dim=$'\e[38;2;108;112;134m' off=$'\e[0m'

while :; do
	# Last pane left in the window: close instead of lingering alone.
	[ "$(tmux display -p -t "$TMUX_PANE" '#{window_panes}')" -gt 1 ] || exit
	ids=()
	out=$'\e[H'"${dim} AGENTS${off}"$'\e[K\n\e[K\n'
	# ponytail: pane whose foreground is a shell = agent exited without reporting off; hidden, not cleared
	while IFS=$'\t' read -r id agent state loc dir cmd; do
		case $cmd in zsh | bash | fish | sh) continue ;; esac
		ids+=("$id")
		c=${col[$state]:-${col[idle]}}
		# 17 cols: number+dot+name / state / location, each line fits
		out+=$(printf ' %d \e[38;2;%sm●%s %.11s' "${#ids[@]}" "$c" "$off" "$agent")$'\e[K\n'
		out+=$(printf '   \e[38;2;%sm%s%s' "$c" "$state" "$off")$'\e[K\n'
		out+=$(printf '   %s%.13s%s' "$dim" "$loc $dir" "$off")$'\e[K\n'
	done < <(tmux list-panes -a -F '#{pane_id}	#{@agent}	#{@agent_state}	#{session_name}:#{window_index}	#{b:pane_current_path}	#{pane_current_command}' |
		awk -F'\t' '$2 != ""')
	[ ${#ids[@]} -eq 0 ] && out+=" ${dim}no agents${off}"$'\e[K\n'
	printf '%s\e[J' "$out"

	read -rsn1 -t1 k
	case $k in
	q) exit ;;
	[1-9])
		id=${ids[k - 1]}
		[ -n "$id" ] && tmux select-window -t "$id" \; select-pane -t "$id" \; switch-client -t "$id"
		;;
	esac
done
