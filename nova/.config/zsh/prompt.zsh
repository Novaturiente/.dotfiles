# Zsh Prompt Configuration

# Disable virtualenv prompt modification
VIRTUAL_ENV_DISABLE_PROMPT=1

# --- Characters (requires a Nerd Font) ---
POWERLINE_CHARS_SEPARATOR=""
POWERLINE_CHARS_BRANCH=""
POWERLINE_CHARS_HOME="🪐"        # Saturn
POWERLINE_CHARS_FOLDER="🌌"      # Galaxy
POWERLINE_CHARS_DOWNLOADS="🌠"   # Shooting Star
POWERLINE_CHARS_DEV="🚀"         # Rocket
POWERLINE_CHARS_TEMP="☄️"         # Comet
POWERLINE_CHARS_GIT=""
POWERLINE_CHARS_PYTHON=""
POWERLINE_CHARS_RUST=""
POWERLINE_CHARS_NODE="󰎙"
POWERLINE_CHARS_DOCKER="🐳"
POWERLINE_CHARS_CONFIG="🛸"      # UFO

# --- Colour scheme ---
# POWERLINE_COLOR_* are set by ~/.config/zsh/colors.zsh, which .zshrc sources
# before this file. scripts/theme.sh regenerates it from the active palette.

# --- Helper Functions ---

# Function to create a styled segment
function make_segment() {
    local content="$1"
    local fg_color="$2"
    echo -n "%{$fg_color%}${content}%{$POWERLINE_COLOR_SEPARATOR_FG%}${POWERLINE_CHARS_SEPARATOR}%{%f%}"
}

# Function to get git status
# One `git status` call gives branch and dirty state (tracked changes vs HEAD,
# untracked files ignored, like the old `git diff --quiet HEAD`).
function get_git_status() {
    (( $+commands[git] )) || return 1

    local line branch state=clean
    for line in ${(f)"$(git status --porcelain=v2 --branch --untracked-files=no --ignore-submodules 2>/dev/null)"}; do
        case $line in
            "# branch.head "*) branch=${line#\# branch.head } ;;
            "#"*) ;;
            *) state=dirty ;;
        esac
    done
    [[ -z $branch || $branch == "(detached)" ]] && return 1

    echo "$branch|$state"
}

# Function to get runtime/language indicators
function get_runtime_indicator() {
    local indicators=()
    [[ -f "pyproject.toml" || -f "requirements.txt" || -f ".python-version" ]] && indicators+=("$POWERLINE_CHARS_PYTHON py")
    [[ -f "Cargo.toml" ]] && indicators+=("$POWERLINE_CHARS_RUST rs")
    [[ -f "package.json" ]] && indicators+=("$POWERLINE_CHARS_NODE js")
    [[ -f "Containerfile" || -f "podman-compose.yml" || -f "Dockerfile" ]] && indicators+=("$POWERLINE_CHARS_DOCKER docker")
    print -rl -- "${indicators[@]}"
}

# --- Main Prompt Functions ---

# Right-side prompt (Time and virtualenv)
function right_prompt() {
    local rprompt=""
    if [ -n "$VIRTUAL_ENV" ]; then
        local venv_name=${VIRTUAL_ENV:h:t}
        local py_version
        local _pylib=($VIRTUAL_ENV/lib/python*(/N:t))
        [[ -n $_pylib ]] && py_version=${_pylib[1]#python}
        rprompt+="$POWERLINE_COLOR_STATUS_FG($venv_name; $py_version) %{%f%} "
    fi
    rprompt+="%{$POWERLINE_COLOR_TIME_FG%}🕐 %D{%H:%M:%S}%{%f%}"
    echo -n "$rprompt"
}

# Main prompt function (Left-side)
function set_prompt() {
    local last_status=$?

    # User segment
    make_segment "$USER" "$POWERLINE_COLOR_USER_FG"

    # Path segment
    local path_display=$(print -P %~)
    local path_icon

    case "$path_display" in
        "~") path_icon=$POWERLINE_CHARS_HOME ;;
        "~/develop"*) path_icon=$POWERLINE_CHARS_DEV ;;
        "~/Downloads"*) path_icon=$POWERLINE_CHARS_DOWNLOADS ;;
        "~/temp"*) path_icon=$POWERLINE_CHARS_TEMP ;;
        "~/.dotfiles"|~/dotfiles) path_icon=$POWERLINE_CHARS_CONFIG ;;
        *) path_icon=$POWERLINE_CHARS_FOLDER ;;
    esac

    make_segment " $path_icon $path_display" "$POWERLINE_COLOR_PATH_FG"

    # Git segment
    local git_output=$(get_git_status)
    if [ -n "$git_output" ]; then
        IFS="|" read -r branch state <<< "$git_output"
        local git_color=$POWERLINE_COLOR_GIT_FG
        [[ "$state" == "dirty" ]] && git_color=$POWERLINE_COLOR_GIT_DIRTY_FG
        make_segment " $POWERLINE_CHARS_GIT $branch" "$git_color"
    fi

    # Runtime/Language indicators
    local runtime_indicators=(${(f)"$(get_runtime_indicator)"})
    for indicator in "${runtime_indicators[@]}"; do
        make_segment " $indicator" "$POWERLINE_COLOR_STATUS_FG"
    done

    # Exit code (if non-zero)
    if [ $last_status -ne 0 ]; then
        make_segment " ✖ $last_status" "$POWERLINE_COLOR_ERROR_FG"
    fi

    # Newline for second line
    echo ""

    # Prompt indicator
    if [ $last_status -eq 0 ]; then
        echo -n "❯ "
    else
        echo -n "%{$POWERLINE_COLOR_ERROR_FG%}❯ %{%f%}"
    fi
}

# Prompt update hook
autoload -Uz add-zsh-hook
add-zsh-hook precmd update_prompt

function update_prompt() {
    PROMPT=$(set_prompt)
    RPROMPT=$(right_prompt)
}

# Initialize prompt
update_prompt

# Vi mode indicator (optional, updates prompt icon)
function zle-line-init zle-keymap-select {
    case $KEYMAP in
        vicmd) PROMPT=${PROMPT//❯/❮} ;;
        *) PROMPT=${PROMPT//❮/❯} ;;
    esac
    zle reset-prompt
}
zle -N zle-line-init
zle -N zle-keymap-select
