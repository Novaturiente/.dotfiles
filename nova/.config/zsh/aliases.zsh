# Editor and system update aliases
# alias vi="nvim"
alias vi="nvim"
alias doom="~/.config/emacs/bin/doom"
alias inova="sudo novarch install"
alias unova="sudo novarch update"
alias anova="sudo novarch add"
alias rnova="sudo novarch remove"

alias cedit="nvim -c 'enew | put + | setlocal buftype=nofile bufhidden=wipe noswapfile'"
alias emacode='emacs -nw --eval "(run-with-idle-timer 1 nil #'\''my/emacode)"'
neocode() {
    if [ -z "$TMUX" ]; then
        echo "neocode requires tmux"
        return 1
    fi
    local tmpdir=$(mktemp -d)
    ln -sf ~/.config/yazi/* "$tmpdir/" 2>/dev/null
    printf '[mgr]\nratio = [0, 1, 0]\n' > "$tmpdir/yazi.toml"
    local cpane=$(tmux split-window -h -d -l 75% -P -F '#{pane_id}')
    tmux set-option -p -t "$cpane" allow-passthrough off
    sleep 1
    tmux send-keys -t "$cpane" 'claude' Enter
    YAZI_CONFIG_HOME="$tmpdir" yazi
    rm -rf "$tmpdir"
}

# Claude project: lazygit (30%) + claude --dangerously-skip-permissions (70%)
# in a persistent tmux session named after the target dir (default: $PWD).
# Inside tmux -> switch-client; outside tmux -> start tmux and attach.
cproj() {
    local dir="${1:-$PWD}"
    dir="${dir:A}"
    [[ -d "$dir" ]] || { echo "cproj: not a directory: $dir" >&2; return 1; }

    local session
    session="$(basename "$dir")"
    session="${session#.}"
    session="${session//:/-}"
    session="${session//./-}"
    session="${session// /_}"

    export PATH="$HOME/.local/bin:${CARGO_HOME:-$HOME/.cargo}/bin:$HOME/.npm-global/bin:${GOPATH:-$HOME/go}/bin:$PATH"
    tmux set-environment -g PATH "$PATH" 2>/dev/null || true

    local lazygit_bin claude_cmd
    lazygit_bin="$(command -v lazygit || echo /usr/bin/lazygit)"
    claude_cmd="$(command -v claude || echo "$HOME/.local/bin/claude") --dangerously-skip-permissions"

    local needs_rebuild=1
    if tmux has-session -t="$session" 2>/dev/null; then
        if [[ "$(tmux list-panes -t "$session" 2>/dev/null | wc -l)" -ge 2 ]]; then
            needs_rebuild=0
        else
            tmux kill-session -t "$session" 2>/dev/null
        fi
    fi

    if [[ "$needs_rebuild" -eq 1 ]]; then
        tmux new-session -d -s "$session" -x 200 -y 50 -c "$dir" "CPROJ=1 $lazygit_bin"
        tmux split-window -h -l 70% -t "$session" -c "$dir" "CPROJ=1 $claude_cmd"
        tmux select-pane -t "$session" -R
    fi

    # Remember the project dir on the session (used by the lazygit<->yazi
    # toggle keybinding to respawn the left pane in the right directory).
    tmux set-option -t "$session" @cproj_dir "$dir" 2>/dev/null || true

    # Focus the claude pane (rightmost) regardless of rebuild/reuse
    local claude_pane
    claude_pane="$(tmux list-panes -t "$session" -F '#{pane_id} #{pane_left}' \
        | sort -k2 -n | tail -1 | cut -d' ' -f1)"
    [[ -n "$claude_pane" ]] && tmux select-pane -t "$claude_pane"

    if [[ -n "$TMUX" ]]; then
        tmux switch-client -t "$session"
    else
        tmux attach-session -t "$session"
    fi
}

# ---- ls Aliases (with eza) ----
alias la='eza -al --color=always --group-directories-first --icons=always "$@"'
alias ls='eza -a --color=always --group-directories-first --icons=always "$@"'
alias ll='eza -l --color=always --group-directories-first --icons=always "$@"'
alias lt='eza -aT --color=always --group-directories-first --icons=always "$@"'
alias l.="eza -a | grep -e '^\.'"

alias rm="trash"

alias cp='rsync -ah --info=progress2 --inplace --no-whole-file'

alias grubup="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias jctl="journalctl -p 3 -xb"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
# alias grep='rg --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias cat='bat --paging=never'

alias gadd='git add . && git commit -m "Update"'
alias hotspot='nmcli dev wifi hotspot ifname wlp0s20f3 ssid Novapc password "$HOTSPOT_PASSWORD"'
alias fileserver="python3 -m http.server 8080 --directory ~/Share"

alias winstart="ssh nova@novahome docker start windows"
alias winstop="ssh nova@novahome docker stop windows"
alias winrestart="ssh nova@novahome docker restart windows"
alias winsopen="ssh nova@novahome docker start windows && winapps windows"

alias macup="podman-compose -f ~/.dotfiles/docker/macos.yaml up -d"
alias macdown="podman-compose -f ~/.dotfiles/docker/macos.yaml down"

# alias novarch="uv run --project ~/.dotfiles/novarch ~/.dotfiles/novarch/run.py"
alias editsystem="nvim ~/.dotfiles/novarch"
alias systemupdate="sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist && paru -Syu"

alias clear-cache="rm -rf ~/.config/qutebrowser_work/cache/* && rm -rf ~/.cache/qutebrowser && rm -rf ~/.cache/floorp"

alias eeclogin="ssh -i ~/.ssh/id_eecdev eecdev@$EEC_SERVER_IP"

alias ar="~/.dotfiles/scripts/tmux_agent.sh"

# yazi (full tree + git signs) + claude --dangerously-skip-permissions, 30:70
alias yproj="~/.dotfiles/scripts/yazi-claude.sh"

alias cld="claude --dangerously-skip-permissions"

alias lsql="lazysql"
