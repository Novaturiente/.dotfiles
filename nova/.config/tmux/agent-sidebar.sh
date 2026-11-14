#!/bin/bash
# Zed-like window: agents sidebar (left), agent (middle), project tree (right), button bar (bottom).
# agent-sidebar.sh toggle <window> [kind] -> prefix+A/E/B: open/close one panel in this window.
# agent-sidebar.sh         -> draw loop, runs inside the sidebar pane.
# agent-sidebar.sh files|bar -> runs inside the project tree / button bar pane.
# agent-sidebar.sh resize -> window-resized hook: keep the panels at their size.
# agent-sidebar.sh next|prev <pane> -> prefix+j/k: jump to the next/previous agent.
# agent-sidebar.sh popup -> prefix+S: sessions and agents in an fzf popup with a live preview.
# agent-sidebar.sh list  -> the popup's rows.
# Keys in the sidebar: 1-9 jump to that agent, q closes.
# Panels are marked by pane option @sidebar: 1 = agents, files = tree, bar = buttons.
WIDTH=12% FILES_WIDTH=18%

# Agent panes, in sidebar order: id, name, state, session:window, folder, command,
# session name (@agent_name, set by novacode; "-" = none), bg count.
# ponytail: pane whose foreground is a shell = agent exited without reporting off; hidden, not cleared
agents() {
	tmux list-panes -a -F '#{pane_id}	#{@agent}	#{@agent_state}	#{session_name}:#{window_index}	#{b:pane_current_path}	#{pane_current_command}	#{@agent_name}	#{@agent_bg}' |
		awk -F'\t' -v OFS='\t' '
			# Known agent not yet reported via hook (e.g. agy before its first prompt): show as idle.
			$2 == "" && $6 ~ /^(agy|claude|codex|novacode)$/ { $2 = $6; $3 = "idle" }
			# Empty field would collapse under IFS=tab in read and shift the columns.
			$3 == "" { $3 = "idle" }
			$7 == "" { $7 = "-" }
			$2 != "" && $6 !~ /^(zsh|bash|fish|sh)$/'
}

# Subscription windows from novacode's quota cache (~/.novacode/cache/usage/<provider>-<account>.json
# per login, <provider>.json = copy for the account used last; refreshed by running novacode
# sessions; Claude Code/codex share the same subscription). $1 = file name without .json.
# Claude: five_hour/seven_day. Codex: primary/secondary window, named by length.
# Rows: name, percent, reset epoch (0 = unknown), data epoch.
usage() {
	jq -r '(.at_ms / 1000 | floor) as $at | .data as $d |
		(if $d.rate_limit then
			$d.rate_limit.primary_window, $d.rate_limit.secondary_window | select(. != null) |
			[(if .limit_window_seconds <= 18000 then "5h" else "wk" end), .used_percent, (.reset_at // 0)]
		else
			["five_hour", "5h"], ["seven_day", "wk"] | . as [$k, $n] | $d[$k] | select(.utilization != null) |
			[$n, .utilization, (.resets_at | if . == null then 0 else sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601 end)]
		end) | "\(.[0])\t\(.[1] | round)\t\(.[2] | floor)\t\($at)"' ~/.novacode/cache/usage/"$1".json 2>/dev/null
}

# Folder -> git repo name (main checkout, so worktrees map back; empty = not a repo).
# ponytail: cached for the sidebar's life; a folder that becomes a repo later shows after a reopen
declare -A rc=()
repo() {
	[ -n "${rc[$1]+x}" ] || rc[$1]=$(r=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && basename "$(dirname "$r")")
	rp=${rc[$1]}
}

# Fills first[session] (folder of its first non-sidebar pane, shown when it has no
# agents), aproj/sproj[session] (project of its first agent / first shell pane).
# Agent project: @agent_project (set by agent-state.sh from edits and folder
# changes), else the repo of the agent's folder; agy/codex never report, so their
# pane folder. '|': empty fields.
projects() {
	declare -gA first=() aproj=() sproj=()
	local s sbp d cmd ag ap acwd full
	while IFS='|' read -r s sbp d cmd ag ap acwd full; do
		[ "$sbp" = s ] && continue
		[ -n "${first[$s]+x}" ] || first[$s]=$d
		rp=$ap
		[ -n "$rp" ] || repo "${acwd:-$full}"
		if [ -n "$ag" ] || [[ $cmd =~ ^(agy|claude|codex|novacode)$ ]]; then
			[ -n "${aproj[$s]}" ] || aproj[$s]=$rp
		else
			[ -n "${sproj[$s]}" ] || sproj[$s]=$rp
		fi
	done < <(tmux list-panes -a -F '#{session_name}|#{?#{@sidebar},s,p}|#{b:pane_current_path}|#{pane_current_command}|#{@agent}|#{@agent_project}|#{@agent_cwd}|#{pane_current_path}')
}

# Sessions (name, windows, project) grouped by project: groups in order of their
# first session, sessions keep their order inside a group, no project last.
# Needs projects() first. Skips scratch, the prefix+t floating terminal's hidden session.
sessions() {
	local -A gi=()
	local n=0 i=0 g name wins pj
	while IFS=$'\t' read -r name wins; do
		[ "$name" = scratch ] && continue
		pj=${aproj[$name]:-${sproj[$name]}} g=99999
		if [ -n "$pj" ]; then
			[ -n "${gi[$pj]+x}" ] || gi[$pj]=$((n++))
			g=${gi[$pj]}
		fi
		printf '%d\t%d\t%s\t%s\t%s\n' "$g" $((i++)) "$name" "$wins" "$pj"
	done < <(tmux list-sessions -F '#{session_name}	#{session_windows}') | sort -t$'\t' -n -k1,1 -k2,2 | cut -f3-
}

goto() { tmux select-window -t "$1" \; select-pane -t "$1" \; switch-client -t "$1"; }

# Catppuccin Mocha: yellow, red, green, overlay0
declare -A col=([working]='249;226;175' [blocked]='243;139;168' [done]='166;227;161' [idle]='108;112;134')
# Agent logo before its name (Nerd Font): Claude and OpenAI logos are real; no
# Antigravity logo exists, so a Gemini-style sparkle; novacode gets a
# four-point star in its logo's lavender.
declare -A logo=(
	[claude]=$'\e[38;2;217;119;87m\uec82' [codex]=$'\e[38;2;205;214;244m\uec81'
	[agy]=$'\e[38;2;137;180;250m\uec21'
	[novacode]=$'\e[38;2;180;167;214m\U000f0ae2'
)
dim=$'\e[38;2;108;112;134m' off=$'\e[0m'

# usage_foot <pane>: fills foot[] with the usage block (label · age, then one row per
# window) for an agent in <pane>'s window: the focused pane if it is one, else the
# one picked last (upane), else the first. So focusing the sidebar keeps the block.
# novacode publishes @agent_model as provider/model and @agent_account (unset on API keys).
# '|' not tab: empty fields collapse under tab IFS.
next_usage=0 src='' shown='-' upane=''
usage_foot() {
	local pick='' fa='' pid a m act c ac ag am acct file em at age u n p r q f bar t
	while IFS='|' read -r pid a m act c ac; do
		[[ $a =~ ^(claude|codex|novacode)$ && ! $c =~ ^(zsh|bash|fish|sh)$ ]] || continue
		[ -n "$fa" ] || fa="$pid|$a|$m|$ac"
		[ "$act" = 1 ] && { pick="$pid|$a|$m|$ac"; break; }
		[ "$pid" = "$upane" ] && pick="$pid|$a|$m|$ac"
	done < <(tmux list-panes -t "$1" -F '#{pane_id}|#{?#{@agent},#{@agent},#{pane_current_command}}|#{@agent_model}|#{pane_active}|#{pane_current_command}|#{@agent_account}')
	IFS='|' read -r upane ag am acct <<<"${pick:-$fa}"
	[ "$ag" = novacode ] && ag=${am%%/*}
	[[ $ag =~ ^(claude|codex)$ ]] && src=$ag || src=''
	# This account's own cache; Claude Code/codex panes (no account) get the last-used copy.
	file=$src
	[ -n "$src" ] && [ -n "$acct" ] && [ -f ~/.novacode/cache/usage/"$src-$acct".json ] && file=$src-$acct
	# ponytail: re-reads the cache every 30s (or on provider/account change); only novacode refreshes it, so the age shows staleness
	if [ "$file" != "$shown" ] || ((SECONDS >= next_usage)); then
		uw=()
		[ -n "$src" ] && mapfile -t uw < <(usage "$file")
		label=${src^^} shown=$file next_usage=$((SECONDS + 30))
		if [ "$file" != "$src" ]; then
			label+=" $acct"
		else
			# No account file: codex's cache still names the login by email.
			em=$(jq -r '.data.email // empty' ~/.novacode/cache/usage/"$src".json 2>/dev/null)
			[ -n "$em" ] && label+=" ${em%%@*}"
		fi
	fi
	foot=()
	[ ${#uw[@]} -gt 0 ] || return 0
	IFS=$'\t' read -r _ _ _ at <<<"${uw[0]}"
	age=$(((EPOCHSECONDS - at) / 60))m
	((${age%m} >= 60)) && age=$((${age%m} / 60))h
	foot=("$(printf ' %s%s · %s ago%s' "$dim" "$label" "$age" "$off")")
	for u in "${uw[@]}"; do
		IFS=$'\t' read -r n p r _ <<<"$u"
		# Smooth gradient: green (0%) -> yellow (50%) -> red (100%), Catppuccin Mocha.
		q=$((p < 0 ? 0 : p > 100 ? 100 : p))
		if ((q <= 50)); then
			c="$((166 + 83 * q / 50));$((227 - q / 50));$((161 + 14 * q / 50))"
		else
			c="$((249 - 6 * (q - 50) / 50));$((226 - 87 * (q - 50) / 50));$((175 - 7 * (q - 50) / 50))"
		fi
		# Window already reset since the cache was written: the percent is meaningless.
		((r > 0 && r <= EPOCHSECONDS)) && c=${col[idle]}
		f=$(((p * 5 + 50) / 100)); ((f > 5)) && f=5
		# Thin bar centred on the text line: filled and empty cells both ━, empty in Catppuccin surface1.
		bar=$(printf '%*s' "$f" '' | sed 's/ /━/g')$'\e[38;2;69;71;90m'$(printf '%*s' $((5 - f)) '' | sed 's/ /━/g')
		t=''
		if ((r > 0 && r <= EPOCHSECONDS)); then
			t=stale
		elif ((r > 0)); then
			if [ "$n" = 5h ]; then t=$(date -d "@$r" +%H:%M); else t=$(date -d "@$r" '+%a %H:%M'); fi
		fi
		foot+=("$(printf ' %s%s%s \e[38;2;%sm%s%s%4d%% %s%s%s' "$dim" "$n" "$off" "$c" "$bar" "$off" "$p" "$dim" "$t" "$off")")
	done
}

# list: popup rows, sesh style, in sidebar order: a session heading (tmux icon, name, project,
# tab count; the popup skips it), then its tabs as a tree: number and command, then each agent
# in the tab (state, logo, conversation name or folder, state), or the tab's folder if none.
# Fields (tab): jump target (=session: for a heading, else the tab's first agent pane or first
# pane), shown text, session name.
if [ "$1" = list ]; then
	projects
	mapfile -t all < <(agents)
	# Per tab: first real pane (panels skipped), its command and folder.
	declare -A tp=() tc=() td=() ta=()
	# '|' not tab: empty fields collapse under tab IFS.
	while IFS='|' read -r loc pid sb cmd d; do
		[ -n "$sb" ] || [ -n "${tp[$loc]}" ] && continue
		tp[$loc]=$pid tc[$loc]=$cmd td[$loc]=$d
	done < <(tmux list-panes -a -F '#{session_name}:#{window_index}|#{pane_id}|#{@sidebar}|#{pane_current_command}|#{b:pane_current_path}')
	for a in "${all[@]}"; do
		IFS=$'\t' read -r id agent state loc dir _ nm _ <<<"$a"
		[ "$nm" = - ] || dir=$nm
		case $state in
		blocked) ic='✱' ;;
		working | 'done') ic='●' ;;
		*) ic='○' ;;
		esac
		# First agent of the tab becomes its jump target.
		[ -n "${ta[$loc]}" ] || tp[$loc]=$id
		ta[$loc]+=$(printf '  \e[38;2;%sm%s%s %s%s %s %s· %s%s' "${col[$state]:-${col[idle]}}" "$ic" "$off" "${logo[$agent]:- }" "$off" "$dir" "$dim" "$state" "$off")
	done
	while IFS=$'\t' read -r name wins pj; do
		printf '=%s:\t\e[38;2;137;180;250m\uebc8%s  \e[1m%s%s  %s%s · %s tab%s%s\t%s\n' \
			"$name" "$off" "$name" "$off" "$dim" "${pj:-no project}" "$wins" "$([ "$wins" = 1 ] || echo s)" "$off" "$name"
		mapfile -t ws < <(tmux list-windows -t "=$name" -F '#{window_index}')
		for k in "${!ws[@]}"; do
			loc=$name:${ws[k]} br='├'
			[ "$k" -eq $((${#ws[@]} - 1)) ] && br='└'
			printf '%s\t  %s%s %s%s %s%s\t%s\n' "${tp[$loc]}" "$dim" "$br" "${ws[k]}" "$off" "${tc[$loc]}" \
				"${ta[$loc]:-  $dim${td[$loc]}$off}" "$name"
		done
	done < <(sessions)
	exit
fi

# popup: prefix+S. fzf over list, cursor on the pane under the popup. Live, but only on change
# (each redraw flickers fzf's cursor and spinner): the list is rebuilt every second and sent
# through fzf's socket when it differs (--track + --id-nth keep the cursor on its row); the
# preview checks the highlighted pane every 0.5s and redraws when its screen differs (\e[2J clears it).
# Top border, full width: title, then the sidebar's usage block (for the agent in the window
# under the popup), spread evenly with border dashes between them.
if [ "$1" = popup ]; then
	cur=$(tmux display -p '#{pane_id}')
	rows=$("$0" list)
	# Background jobs get no terminal: measure the popup now.
	read -r _ cols < <(stty size)
	shopt -s extglob
	blabel() {
		usage_foot "$cur"
		local it=($'\e[1m \U000f06a9 agents \e[0m') x len=0 g gaps fill i out=''
		for x in "${foot[@]}"; do it+=("$x "); done
		for x in "${it[@]}"; do x=${x//$'\e['*([0-9;])m/}; len=$((len + ${#x})); done
		# Between the corners, one dash kept at each end.
		fill=$((cols - 4 - len)) gaps=$((${#it[@]} - 1))
		for i in "${!it[@]}"; do
			out+=${it[i]}
			((i < gaps)) || break
			g=$((fill / gaps))
			((i == gaps - 1)) && g=$((fill - fill / gaps * (gaps - 1)))
			out+=$dim$(printf '%*s' "$((g < 1 ? 1 : g))" '' | sed 's/ /─/g')$off
		done
		blab=$out
	}
	blabel
	head=$blab
	# Session headings (target =...) are skipped: moving onto one moves once more; at the top,
	# where up cannot move, it goes back down. bash, not $SHELL: zsh expands a leading = in =*.
	skipd='down+transform:[[ {1} == =* ]] && echo down'
	skipu='up+transform:[[ {1} == =* ]] && { [ "$FZF_POS" = 1 ] && echo down || echo up; }'
	# Start on the pane under the popup, else its tab's row (whose target is another pane of the tab).
	n=$(awk -F'\t' -v c="$cur" '$1 == c {print NR; exit}' <<<"$rows")
	if [ -z "$n" ]; then
		mapfile -t tps < <(tmux list-panes -F '#{pane_id}')
		n=$(awk -F'\t' -v ps=" ${tps[*]} " 'index(ps, " " $1 " ") {print NR; exit}' <<<"$rows")
	fi
	sock=${XDG_RUNTIME_DIR:-/tmp}/tmux-agents-$$.sock rf=${XDG_RUNTIME_DIR:-/tmp}/tmux-agents-$$.rows
	(
		prev=$rows prevh=$head
		while sleep 1; do
			[ -S "$sock" ] || continue
			blabel
			h=$blab
			if [ "$h" != "$prevh" ]; then
				curl -s --unix-socket "$sock" http://fzf -d "change-border-label:$h" || break
				prevh=$h
			fi
			new=$("$0" list)
			[ "$new" = "$prev" ] && continue
			printf '%s\n' "$new" >"$rf" && prev=$new
			curl -s --unix-socket "$sock" http://fzf -d "reload-sync(cat '$rf')" || break
		done
	) &
	loop=$!
	trap 'kill "$loop" 2>/dev/null; rm -f "$sock" "$rf"' EXIT HUP TERM
	sel=$(fzf --ansi --no-sort --track --id-nth 1 --delimiter '\t' --with-nth 2 --listen "$sock" \
		--layout reverse --border rounded --border-label "$head" --color 'border:#6c7086' --pointer '▎' \
		--padding 1,2 --no-input --bind 'q:abort' --with-shell 'bash -c' \
		--bind "j:$skipd" --bind "down:$skipd" --bind "k:$skipu" --bind "up:$skipu" \
		--bind "load:pos(${n:-2})+unbind(load)" \
		--bind "ctrl-d:execute-silent(tmux kill-session -t ={3})+reload-sync($0 list)" \
		--preview 'p=; while :; do s=$(tmux capture-pane -ep -t {1}); [ "$s" = "$p" ] || { printf "\033[2J%s\n" "$s"; p=$s; }; sleep 0.5; done' \
		--preview-window 'right,60%,border-left' <<<"$rows")
	[ -n "$sel" ] && goto "${sel%%$'\t'*}"
	exit 0
fi

if [ "$1" = next ] || [ "$1" = prev ]; then
	# Same order as the sidebar: agents session by session, sessions grouped.
	projects
	mapfile -t all < <(agents)
	ids=()
	while IFS=$'\t' read -r name _; do
		for a in "${all[@]}"; do
			IFS=$'\t' read -r id _ _ loc _ <<<"$a"
			[ "${loc%:*}" = "$name" ] && ids+=("$id")
		done
	done < <(sessions)
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
# seen <session>: client-session-changed hook. Opening a session counts as looking at its
# finished agents: done -> idle, which also clears them from the agent notes popup (agent-notes.sh).
if [ "$1" = seen ]; then
	tmux list-panes -s -t "$2" -F '#{pane_id} #{@agent_state}' 2>/dev/null |
		awk '$2 == "done" {print $1}' | xargs -rI{} tmux set -p -t {} @agent_state idle
	exit 0
fi
# reap <window>: pane-exited/after-kill-pane hook. Only panels/novacode panels (@slot) left ->
# close the window, so a session dies with its last real pane.
if [ "$1" = reap ]; then
	tmux list-panes -t "$2" -F '#{?#{||:#{@sidebar},#{@slot}},1,0}' 2>/dev/null | grep -qx 0 || tmux kill-window -t "$2" 2>/dev/null
	exit 0
fi
# poke: session-closed hook. SIGUSR1 to each sidebar's draw loop = redraw now,
# no 1s polling lag and no keys typed into any pane.
if [ "$1" = poke ]; then
	# @sidebar_pid, not pane_pid: under fish pane_pid is the `fish -c` wrapper, which USR1 kills.
	tmux list-panes -a -F '#{@sidebar} #{@sidebar_pid}' | awk '$1 == 1 && $2 {print $2}' | xargs -r kill -USR1 2>/dev/null
	exit 0
fi
# open <window>: hooks. Like toggle but never closes, and skipped mid-restore.
# Window mode @mode: regular = plain tmux, ide = panels; unset = ide while some agent exists.
if [ "$1" = open ]; then
	# Gone, or the floating terminal's session (never gets panels).
	s=$(tmux display -p -t "$2" '#{session_name}' 2>/dev/null)
	[ -n "$s" ] && [ "$s" != scratch ] || exit 0
	m=$(tmux show -wqv -t "$2" @mode)
	[ "$m" = regular ] && exit 0
	[ "$m" = ide ] || [ -n "$(agents)" ] || exit 0
fi
# mode <window>: prefix+I. Panels showing -> regular (close them all), else -> ide.
if [ "$1" = mode ]; then
	ps=$(tmux list-panes -t "$2" -F '#{pane_id} #{@sidebar}' | awk '$2 != "" {print $1}')
	if [ -n "$ps" ]; then
		tmux set -w -t "$2" @mode regular
		for p in $ps; do tmux kill-pane -t "$p"; done
		tmux display 'regular mode'
		exit 0
	fi
	tmux set -w -t "$2" @mode ide \; set -wu -t "$2" @sidebar_off \; set -wu -t "$2" @bar_off
	set -- open "$2"
fi
# panel <window> <kind>: pane id of that panel, empty if closed.
panel() { tmux list-panes -t "$1" -F '#{pane_id} #{@sidebar}' | awk -v k="$2" '$2 == k {print $1}'; }
# Window flag: 1 = closed by hand, 0 = opened by hand. Hooks open the bar unless closed
# by hand; the agents sidebar and the tree start collapsed, so only after a toggle opened them.
off_opt() { if [ "$1" = 1 ]; then echo @sidebar_off; else echo "@$1_off"; fi; }
wanted() {
	local v
	v=$(tmux show -wqv -t "$1" "$(off_opt "$2")")
	if [ "$2" = bar ]; then [ "$v" != 1 ]; else [ "$v" = 0 ]; fi
}
# add <window> <kind>: split the panel, print its pane id.
add() {
	case $2 in
	1) tmux split-window -t "$1" -hbfdP -F '#{pane_id}' -l "$WIDTH" "$0" ;;
	files)
		# Repo root of the window's first real pane, like Zed's project panel.
		local d
		d=$(tmux list-panes -t "$1" -F '#{?#{@sidebar},,#{pane_current_path}}' | grep -m1 .)
		d=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || echo "$d")
		tmux split-window -t "$1" -hfdP -F '#{pane_id}' -l "$FILES_WIDTH" -c "$d" "$0 files"
		;;
	bar) tmux split-window -t "$1" -vfdP -F '#{pane_id}' -l 1 "$0 bar" ;;
	esac
}
if [ "$1" = toggle ] || [ "$1" = resize ] || [ "$1" = open ]; then
	# new-window fires after-new-window and session-window-changed together; without the
	# lock both opens see no sidebar and each splits one.
	exec 9>"${XDG_RUNTIME_DIR:-/tmp}/tmux-agent-sidebar.lock" && flock 9
	kinds='1 files bar'
	[ "$1" = toggle ] && kinds=${3:-1}
	[ "$1" = resize ] && kinds=''
	[ "$1" != open ] || [ -z "$(tmux show -gqv @restoring)" ] || exit 0
	hadbar=$(panel "$2" bar) added=''
	for k in $kinds; do
		p=$(panel "$2" "$k") o=$(off_opt "$k")
		if [ -n "$p" ]; then
			[ "$1" = toggle ] && tmux kill-pane -t "$p" \; set -w -t "$2" "$o" 1
		elif [ "$1" = toggle ] || wanted "$2" "$k"; then
			# Mark before the lock drops so the next open sees it.
			new=$(add "$2" "$k") && tmux set -p -t "$new" @sidebar "$k" \; set -w -t "$2" "$o" 0
			[ "$k" = bar ] || added=1
		fi
	done
	# A new full-height side panel also covers the bar's row: rebuild the bar so it spans the bottom again.
	if [ -n "$added" ] && [ -n "$hadbar" ]; then
		tmux kill-pane -t "$hadbar"
		new=$(add "$2" bar) && tmux set -p -t "$new" @sidebar bar
	fi
	# Each split shrinks the others: set every panel back to its size.
	p=$(panel "$2" 1) && [ -n "$p" ] && tmux resize-pane -t "$p" -x "$WIDTH"
	p=$(panel "$2" files) && [ -n "$p" ] && tmux resize-pane -t "$p" -x "$FILES_WIDTH"
	p=$(panel "$2" bar) && [ -n "$p" ] && tmux resize-pane -t "$p" -y 1
	exit 0
fi

# Project tree: explorenova's tree-only mode. Quitting it (q) counts as closing by hand.
if [ "$1" = files ]; then
	tmux select-pane -t "$TMUX_PANE" -T files
	explorenova -t "$PWD"
	tmux set -w -t "$TMUX_PANE" @files_off 1 2>/dev/null
	exit 0
fi

# Button bar, Zed's bottom row: agents toggle on the left; lazygit, scratch shell,
# explorenova popup and tree toggle on the right. Blue = panel open.
if [ "$1" = bar ]; then
	tmux select-pane -t "$TMUX_PANE" -T bar
	printf '\e[?25l\e[?7l\e[?1000h\e[?1006h'
	trap 'printf "\e[?25h\e[?7h\e[?1000l\e[?1006l"' EXIT
	on=$'\e[38;2;137;180;250m' dim=$'\e[38;2;108;112;134m' off=$'\e[0m' last=''
	while :; do
		read -r np vis w wid cl < <(tmux display -p -t "$TMUX_PANE" '#{window_panes} #{&&:#{window_active},#{session_attached}} #{pane_width} #{window_id} #{client_name}')
		[ "$np" -gt 1 ] || exit
		if [ "$vis" != 1 ]; then
			last=''
			sleep 1
			continue
		fi
		ks=" $(tmux list-panes -t "$TMUX_PANE" -F '#{@sidebar}' | tr '\n' ' ')"
		ac=$dim fc=$dim
		[[ $ks == *" 1 "* ]] && ac=$on
		[[ $ks == *" files "* ]] && fc=$on
		# Right buttons at columns w-10, w-7, w-4, w-1 (click map below).
		out=$(printf ' %s\uebf3%s\e[%dG%s\uea68  \uea85  \ueaf0  %s\uebf4%s' "$ac" "$off" $((w - 10)) "$dim" "$fc" "$off")
		[ "$out" = "$last" ] || { printf '\e[H\e[2K%s' "$out"; last=$out; }
		read -rsn1 -t1 k || continue
		[ "$k" = $'\e' ] || continue
		seq=''
		while read -rsn1 -t0.05 c; do
			seq+=$c
			[[ $c == [Mm] ]] && break
		done
		[[ $seq =~ ^\[\<0\;([0-9]+)\;[0-9]+M$ ]] || continue
		x=${BASH_REMATCH[1]}
		# The click focused the bar; hand focus back so popups open on the agent's folder.
		tmux last-pane -t "$TMUX_PANE" 2>/dev/null
		# Toggles run in the server: a side panel rebuilds this bar, which would kill a child of it.
		if ((x <= 3)); then tmux run-shell -b "'$0' toggle '$wid' 1"
		elif ((x >= w - 2)); then tmux run-shell -b "'$0' toggle '$wid' files"
		# Popups: press the prefix bindings (e, t, g) for the client; & so an open popup never blocks the bar.
		elif ((x >= w - 5)); then tmux send-keys -K -c "$cl" '`' e &
		elif ((x >= w - 8)); then tmux send-keys -K -c "$cl" '`' t &
		elif ((x >= w - 11)); then tmux send-keys -K -c "$cl" '`' g &
		fi
		last=''
	done
fi

tmux set -p -t "$TMUX_PANE" @sidebar 1 \; set -p -t "$TMUX_PANE" @sidebar_pid $$ \; select-pane -t "$TMUX_PANE" -T agents
# Hide cursor, no line wrap (long rows clip instead of breaking the layout);
# SGR mouse reporting so clicks reach the draw loop.
printf '\e[?25l\e[?7l\e[?1000h\e[?1006h'
trap 'printf "\e[?25h\e[?7h\e[?1000l\e[?1006l"' EXIT
# poke: a trapped signal cuts the pending read short; the frame loop then refreshes.
wake=''
trap 'wake=1' USR1

# Animation: working = braille spinner, blocked = red icon fading in and out.
# Lines carry @W@/@B@ placeholders, swapped for the current frame at each redraw.
spin=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
pulse=('243;139;168' '206;118;143' '168;97;118' '131;76;93' '168;97;118' '206;118;143')
fr=0

mt=$(stat -Lc %Y "$0")
while :; do
	# Script edited: restart on the new code, so no sidebar keeps drawing the old way.
	[ "$(stat -Lc %Y "$0")" = "$mt" ] || exec "$0"
	read -r np vis h w me < <(tmux display -p -t "$TMUX_PANE" '#{window_panes} #{&&:#{window_active},#{session_attached}} #{pane_height} #{pane_width} #{session_name}')
	# Last pane left in the window: close instead of lingering alone.
	[ "$np" -gt 1 ] || exit
	# Not on screen (another window, or no client attached): skip gathering and drawing.
	# A poke (USR1) cuts the wait short; last='' forces a full redraw once visible again.
	if [ "$vis" != 1 ]; then
		last='' wake=''
		sleep 1 & wait $!
		continue
	fi
	# Selected agent = active pane of this session's active window.
	sel=$(tmux display -p -t "$me:" '#{pane_id}')

	usage_foot "$TMUX_PANE"
	# Tree: project heading, its sessions, each session's agents under it.
	# rows = click target per screen line (p:<pane> or s:<session>), parallel to
	# lines. Agent numbers (1-9 keys) run across sessions in the same order as prefix+j/k.
	mapfile -t all < <(agents)
	projects
	ids=() lines=("" "${dim} SESSIONS${off}") rows=("" "")
	myproj=${aproj[$me]:-${sproj[$me]}} prevpj=$'\n'
	while IFS=$'\t' read -r name wins pj; do
		# Project heading once per group, a blank line before each group; sessions
		# with no project come last, with no heading. Bold blue = this session's
		# project, Catppuccin text (white) for the others.
		if [ "$pj" != "$prevpj" ]; then
			lines+=("") rows+=("")
			if [ -n "$pj" ]; then
				pc='205;214;244'
				[ "$pj" = "$myproj" ] && pc='137;180;250'
				lines+=("$(printf ' \e[1;38;2;%sm%.*s%s' "$pc" $((w - 2)) "$pj" "$off")") rows+=("")
			fi
			prevpj=$pj
		fi
		# Mauve name = this session, plain otherwise.
		nc=''
		[ "$name" = "$me" ] && nc=$'\e[1;38;2;203;166;247m'
		lines+=("$(printf ' %s%-20.20s%s %s%sw%s' "$nc" "$name" "$off" "$dim" "$wins" "$off")")
		rows+=("s:$name")
		mine=()
		for a in "${all[@]}"; do
			IFS=$'\t' read -r _ _ _ loc _ <<<"$a"
			[ "${loc%:*}" = "$name" ] && mine+=("$a")
		done
		if [ ${#mine[@]} -eq 0 ]; then
			lines+=("$(printf '   %s%.24s%s' "$dim" "${first[$name]}" "$off")") rows+=("s:$name")
		fi
		for k in "${!mine[@]}"; do
			IFS=$'\t' read -r id agent state loc dir _ nm nbg <<<"${mine[k]}"
			# Session name novacode gave the conversation, in place of the folder.
			[ "$nm" = - ] || dir=$nm
			ids+=("$id") rows+=("p:$id")
			c=${col[$state]:-${col[idle]}}
			case $state in
			working) ic=@W@ sw=working ;;
			blocked) ic=@B@ sw=waiting ;;
			# Finished, not yet looked at; pane-focus-in turns it back to idle.
			'done') ic=$'\e[38;2;'$c'm●' sw='' ;;
			*) ic=$'\e[38;2;'$c'm○' sw=$state ;;
			esac
			br='├' cont='│'
			[ "$k" -eq $((${#mine[@]} - 1)) ] && br='└' cont=' '
			# Selected: mauve bar in the gutter + bold name.
			g=' ' b=''
			[ "$id" = "$sel" ] && g=$'\e[38;2;203;166;247m▎\e[0m' b=$'\e[1m'
			# Name 2 columns narrower than before to make room for the logo.
			lines+=("$(printf '%s%s%s%s %s%s %s%s %s%-8.8s%s \e[38;2;%sm%s%s' "$g" "$dim" "$br" "$off" "$ic" "$off" "${logo[$agent]:- }" "$off" "$b" "$agent" "$off" "$c" "$sw" "$off")")
			# Background processes (@agent_bg): blue gear + count before the folder, apart from the state.
			# Wrapped at word breaks to the pane width (5 columns of tree prefix, 1 spare);
			# lines after the first indent past the gear.
			bgm='' bw=0
			[ -n "$nbg" ] && bgm=$'\e[38;2;137;180;250m⚙'$nbg' ' bw=$((${#nbg} + 2))
			dw=$((w - 6 - bw)); ((dw < 4)) && dw=4
			lead=$bgm
			while IFS= read -r part; do
				lines+=("$(printf '%s%s%s%s   %s\e[38;2;166;173;200m%s%s' "$g" "$dim" "$cont" "$off" "$lead" "$part" "$off")") rows+=("p:$id")
				lead=$(printf '%*s' "$bw" '')
			done < <(fold -s -w "$dw" <<<"$dir")
		done
	done < <(sessions)

	# ponytail: clipped at pane height, no scrolling; add it if sessions+agents outgrow the pane
	# Usage pinned to the bottom: list gets the rest, padded so the footer sits on the last rows.
	# Last row stays blank so nothing touches the bottom edge.
	bh=$((h - ${#foot[@]} - 1))
	lines=("${lines[@]:0:bh}") rows=("${rows[@]:0:bh}")
	while [ ${#foot[@]} -gt 0 ] && [ ${#lines[@]} -lt "$bh" ]; do lines+=(""); done
	lines+=("${foot[@]}" "")
	# Data refreshes once a second; the frame redraws 4x a second for the animation.
	# A key, click or poke (also one that landed while gathering) breaks out at once.
	for _ in 1 2 3 4; do
		# $(...) drops the final newline, so a full-height list never scrolls.
		out=$(printf '%s\e[K\n' "${lines[@]}")
		out=${out//@W@/$'\e[38;2;'${col[working]}'m'${spin[fr % 10]}}
		out=${out//@B@/$'\e[38;2;'${pulse[fr % 6]}'m✱'}
		((fr++))
		# Unchanged frame (nothing animating, same data): no output, so tmux and the terminal stay idle.
		[ "$out" = "$last" ] || { printf '\e[H%s\e[J' "$out"; last=$out; }
		# Posix mode only for this read: plain bash restarts a read after a trap, posix
		# mode returns from it, so a poke lands at once instead of at the 0.25s timeout.
		if [ -z "$wake" ]; then
			set -o posix
			read -rsn1 -t0.25 k
			rc=$?
			set +o posix
			((rc == 0)) && break
		fi
		[ -n "$wake" ] && { wake='' k=''; break; }
	done
	case $k in
	q) exit ;;
	$'\e')
		# Mouse: ESC [ < button ; col ; row M  (M = press). Left click only.
		seq=''
		while read -rsn1 -t0.05 c; do
			seq+=$c
			[[ $c == [Mm] ]] && break
		done
		[[ $seq =~ ^\[\<0\;[0-9]+\;([0-9]+)M$ ]] || continue
		t=${rows[BASH_REMATCH[1] - 1]}
		[ -n "$t" ] || continue
		# The click focused the sidebar; hand focus back before jumping.
		tmux last-pane -t "$TMUX_PANE" 2>/dev/null
		case $t in
		p:*) goto "${t#p:}" ;;
		s:*) tmux switch-client -t "=${t#s:}" ;;
		esac
		;;
	[1-9])
		id=${ids[k - 1]}
		[ -n "$id" ] && goto "$id"
		;;
	esac
done
