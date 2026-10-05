#!/bin/bash
# agent-sidebar.sh toggle  -> prefix+A: open/close the sidebar in this window.
# agent-sidebar.sh         -> draw loop, runs inside the sidebar pane.
# agent-sidebar.sh resize -> window-resized hook: keep the sidebar at WIDTH.
# agent-sidebar.sh next|prev <pane> -> prefix+j/k: jump to the next/previous agent.
# Keys in the sidebar: 1-9 jump to that agent, q closes.
WIDTH=15%

# Agent panes, in sidebar order: id, name, state, session:window, folder.
# ponytail: pane whose foreground is a shell = agent exited without reporting off; hidden, not cleared
agents() {
	tmux list-panes -a -F '#{pane_id}	#{@agent}	#{@agent_state}	#{session_name}:#{window_index}	#{b:pane_current_path}	#{pane_current_command}' |
		awk -F'\t' -v OFS='\t' '
			# Known agent not yet reported via hook (e.g. agy before its first prompt): show as idle.
			$2 == "" && $6 ~ /^(agy|claude|pi|codex)$/ { $2 = $6; $3 = "idle" }
			$2 != "" && $6 !~ /^(zsh|bash|fish|sh)$/'
}

goto() { tmux select-window -t "$1" \; select-pane -t "$1" \; switch-client -t "$1"; }

if [ "$1" = next ] || [ "$1" = prev ]; then
	mapfile -t ids < <(agents | cut -f1)
	n=${#ids[@]}
	[ "$n" -eq 0 ] && { tmux display 'no agents'; exit; }
	i=-1
	for j in "${!ids[@]}"; do [ "${ids[j]}" = "$2" ] && i=$j; done
	if [ "$1" = next ]; then
		i=$(((i + 1) % n))
	else
		[ "$i" -lt 0 ] && i=0
		i=$(((i - 1 + n) % n))
	fi
	goto "${ids[i]}"
	exit
fi
# reap <window>: pane-exited/after-kill-pane hook. Only sidebars left -> close the
# window, so a session dies with its last real pane.
if [ "$1" = reap ]; then
	tmux list-panes -t "$2" -F '#{@sidebar}' 2>/dev/null | grep -qvx 1 || tmux kill-window -t "$2" 2>/dev/null
	exit 0
fi
if [ "$1" = toggle ] || [ "$1" = resize ]; then
	sb=$(tmux list-panes -t "$2" -F '#{pane_id} #{@sidebar}' | awk '$2 == 1 {print $1}')
	if [ "$1" = resize ]; then
		[ -n "$sb" ] && tmux resize-pane -t "$sb" -x "$WIDTH"
	elif [ -n "$sb" ]; then
		tmux kill-pane -t "$sb"
	else
		tmux split-window -t "$2" -hbfd -l "$WIDTH" "$0"
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
	read -r h me < <(tmux display -p -t "$TMUX_PANE" '#{pane_height} #{session_name}')
	ids=() top=("${dim} AGENTS${off}" "")
	while IFS=$'\t' read -r id agent state loc dir _; do
		ids+=("$id")
		c=${col[$state]:-${col[idle]}}
		top+=("$(printf ' %d \e[38;2;%sm●%s %-8.8s \e[38;2;%sm%-7s%s' "${#ids[@]}" "$c" "$off" "$agent" "$c" "$state" "$off")")
		top+=("$(printf '   %s%.28s%s' "$dim" "$loc $dir" "$off")")
	done < <(agents)
	[ ${#ids[@]} -eq 0 ] && top+=(" ${dim}no agents running${off}")

	# Sessions pinned to the bottom: green dot = attached, mauve name = this one.
	bot=("" "${dim} SESSIONS${off}")
	# Folder of each session's first non-sidebar pane.
	declare -A first=()
	while IFS=$'\t' read -r s sbp d; do
		[ "$sbp" = s ] || [ -n "${first[$s]+x}" ] || first[$s]=$d
	done < <(tmux list-panes -a -F '#{session_name}	#{?#{@sidebar},s,p}	#{b:pane_current_path}')
	while IFS=$'\t' read -r name wins att; do
		d=${col[idle]} nc=''
		[ "$att" -gt 0 ] && d=${col[done]}
		[ "$name" = "$me" ] && nc=$'\e[1;38;2;203;166;247m'
		bot+=("$(printf ' \e[38;2;%sm●%s %s%-18.18s%s %s%sw%s' "$d" "$off" "$nc" "$name" "$off" "$dim" "$wins" "$off")")
		bot+=("$(printf '   %s%.24s%s' "$dim" "${first[$name]}" "$off")")
	done < <(tmux list-sessions -F '#{session_name}	#{session_windows}	#{session_attached}')

	while [ $((${#top[@]} + ${#bot[@]})) -lt "$h" ]; do top+=(""); done
	# $(...) drops the final newline, so a full-height list never scrolls.
	printf '\e[H%s\e[J' "$(printf '%s\e[K\n' "${top[@]}" "${bot[@]}")"

	read -rsn1 -t1 k
	case $k in
	q) exit ;;
	[1-9])
		id=${ids[k - 1]}
		[ -n "$id" ] && goto "$id"
		;;
	esac
done
