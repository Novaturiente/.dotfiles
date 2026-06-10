# Auto-activate / deactivate Python venv on directory change.
# Replaces the zsh `auto-venv` plugin.  Walks up for .venv or venv.
function __auto_venv --on-variable PWD
    status is-command-substitution; and return

    set -l dir $PWD
    set -l found
    while test "$dir" != /
        if test -e "$dir/.venv/bin/activate.fish"
            set found "$dir/.venv"; break
        else if test -e "$dir/venv/bin/activate.fish"
            set found "$dir/venv"; break
        end
        set dir (path dirname $dir)
    end

    if test -n "$found"
        if test "$VIRTUAL_ENV" != "$found"
            type -q deactivate; and deactivate
            source "$found/bin/activate.fish"
        end
    else if set -q VIRTUAL_ENV
        type -q deactivate; and deactivate
    end
end
