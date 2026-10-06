# Plain `tmux`: attach to the last session if a server runs, else start one
# (through tmux.service where installed, so it saves on shutdown).
# Inside tmux: session picker instead of nesting. With args: unchanged.
function tmux --wraps tmux
    if test (count $argv) -gt 0
        command tmux $argv
    else if set -q TMUX
        command tmux choose-session
    else
        command tmux has-session 2>/dev/null; or systemctl --user start tmux.service 2>/dev/null
        command tmux attach 2>/dev/null; or command tmux new-session
    end
end
