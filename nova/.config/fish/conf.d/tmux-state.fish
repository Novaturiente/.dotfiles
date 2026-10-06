# Inside tmux: every cd saves tmux state, so a restore reopens panes in their last folder.
if set -q TMUX
    function _tmux_state_save --on-variable PWD
        ~/.config/tmux/state.sh save 2>/dev/null
    end
end
