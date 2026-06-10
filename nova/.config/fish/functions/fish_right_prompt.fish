# Right prompt — venv indicator + clock (ported from right_prompt() in prompt.zsh)
function fish_right_prompt
    if set -q VIRTUAL_ENV
        set -l vname (basename (dirname $VIRTUAL_ENV))
        set -l pyver (python -c 'import platform; print(platform.python_version())' 2>/dev/null)
        set_color 32CD32
        echo -n "($vname; $pyver)  "
        set_color normal
    end
    set_color 6A5ACD
    echo -n "🕐 "(date '+%H:%M:%S')
    set_color normal
end
