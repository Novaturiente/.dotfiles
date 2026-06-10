# yazi (left, narrow) + claude in a tmux split.  Ported from aliases.zsh.
function neocode
    if test -z "$TMUX"
        echo "neocode requires tmux"
        return 1
    end
    set -l tmpdir (mktemp -d)
    ln -sf ~/.config/yazi/* $tmpdir/ 2>/dev/null
    printf '[mgr]\nratio = [0, 1, 0]\n' >$tmpdir/yazi.toml
    set -l cpane (tmux split-window -h -d -l 75% -P -F '#{pane_id}')
    tmux set-option -p -t "$cpane" allow-passthrough off
    sleep 1
    tmux send-keys -t "$cpane" 'claude' Enter
    env YAZI_CONFIG_HOME=$tmpdir yazi
    rm -rf $tmpdir
end
