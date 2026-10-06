# Plain `tmux`: attach to the last session if a server runs, else start one.
# Inside tmux: session picker instead of nesting. With args: unchanged.
function tmux --wraps tmux
    if test (count $argv) -gt 0
        command tmux $argv
    else if set -q TMUX
        command tmux choose-session
    else
        command tmux attach 2>/dev/null; or command tmux new-session
    end
end
