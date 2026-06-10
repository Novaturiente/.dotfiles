# Persistent tmux project session: lazygit (30%) + claude (70%).
# Ported from aliases.zsh cproj().
function cproj
    set -l dir $argv[1]
    test -z "$dir"; and set dir $PWD
    set dir (realpath -- $dir)
    if not test -d "$dir"
        echo "cproj: not a directory: $dir" >&2
        return 1
    end

    set -l session (basename $dir)
    set session (string replace -r '^\.' '' -- $session)
    set session (string replace -a ':' '-' -- $session)
    set session (string replace -a '.' '-' -- $session)
    set session (string replace -a ' ' '_' -- $session)

    set -gx PATH $HOME/.local/bin $HOME/.cargo/bin $HOME/.npm-global/bin $HOME/go/bin $PATH
    tmux set-environment -g PATH (string join ':' $PATH) 2>/dev/null

    set -l lazygit_bin (command -v lazygit); or set lazygit_bin /usr/bin/lazygit
    set -l claude_bin (command -v claude); or set claude_bin $HOME/.local/bin/claude
    set -l claude_cmd "$claude_bin --dangerously-skip-permissions"

    set -l needs_rebuild 1
    if tmux has-session -t=$session 2>/dev/null
        if test (tmux list-panes -t $session 2>/dev/null | wc -l) -ge 2
            set needs_rebuild 0
        else
            tmux kill-session -t $session 2>/dev/null
        end
    end

    if test $needs_rebuild -eq 1
        tmux new-session -d -s $session -x 200 -y 50 -c "$dir" "CPROJ=1 $lazygit_bin"
        tmux split-window -h -l 70% -t $session -c "$dir" "CPROJ=1 $claude_cmd"
        tmux select-pane -t $session -R
    end

    tmux set-option -t $session @cproj_dir "$dir" 2>/dev/null

    set -l claude_pane (tmux list-panes -t $session -F '#{pane_id} #{pane_left}' | sort -k2 -n | tail -1 | cut -d' ' -f1)
    test -n "$claude_pane"; and tmux select-pane -t "$claude_pane"

    if test -n "$TMUX"
        tmux switch-client -t $session
    else
        tmux attach-session -t $session
    end
end
