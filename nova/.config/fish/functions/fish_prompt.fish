# Left prompt — ported from prompt.zsh (powerline, fg-only segments).
function fish_prompt
    set -l last_status $status

    # --- User segment (blue) ---
    _pl_seg "$USER" 007ACC

    # --- Path segment (grey) with context icon ---
    set -l disp (string replace -- $HOME '~' $PWD)
    set -l icon 📁                          # default: folder
    switch $disp
        case '~';            set icon 🐧
        case '~/develop*';   set icon 💻
        case '~/Downloads*'; set icon 📥
        case '~/temp*';      set icon 🧹
        case '~/.dotfiles' '~/dotfiles'; set icon 🛠️
    end
    _pl_seg " $icon $disp" CCCCCC

    # --- Git segment (green clean / red dirty) ---
    set -l branch (git branch --show-current 2>/dev/null)
    if test -n "$branch"
        set -l gcol 8FBC8F
        if not git diff --quiet --ignore-submodules HEAD 2>/dev/null
            set gcol FF6B6B
        end
        _pl_seg "  $branch" $gcol
    end

    # --- Runtime / language indicators (green) ---
    test -f pyproject.toml -o -f requirements.txt -o -f .python-version; and _pl_seg "  py" 32CD32
    test -f Cargo.toml;                                                   and _pl_seg "  rs" 32CD32
    test -f package.json;                                                 and _pl_seg " 󰎙 js" 32CD32
    test -f Containerfile -o -f podman-compose.yml -o -f Dockerfile;      and _pl_seg " 🐳 podman" 32CD32

    # --- Exit code (red, only if non-zero) ---
    test $last_status -ne 0; and _pl_seg "  $last_status" FF4500

    # --- Second line: vi-mode-aware prompt char ---
    echo
    set -l arrow ❯                            # insert mode
    test "$fish_bind_mode" = default; and set arrow ❮   # command/normal mode
    if test $last_status -eq 0
        echo -n "$arrow "
    else
        set_color FF4500; echo -n "$arrow "; set_color normal
    end
end
