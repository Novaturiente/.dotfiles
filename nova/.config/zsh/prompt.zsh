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

# --- Color Scheme (Foreground colors only) ---
POWERLINE_COLOR_USER_FG="%F{#A15BFF}"        # Nebula Violet
POWERLINE_COLOR_PATH_FG="%F{#00E5FF}"        # Starlight Cyan
POWERLINE_COLOR_GIT_FG="%F{#FF5BBE}"         # Cosmic Pink
POWERLINE_COLOR_GIT_DIRTY_FG="%F{#FF007F}"   # Supernova Magenta
POWERLINE_COLOR_TIME_FG="%F{#8A8F98}"        # Stardust Grey
POWERLINE_COLOR_STATUS_FG="%F{#3FF3FF}"      # Neutron Star Blue
POWERLINE_COLOR_ERROR_FG="%F{#FF3B30}"
POWERLINE_COLOR_SEPARATOR_FG="%F{#4A4A5A}"

# --- Helper Functions ---

# Function to create a styled segment
function make_segment() {
    local content="$1"
    local fg_color="$2"
    echo -n "%{$fg_color%}${content}%{$POWERLINE_COLOR_SEPARATOR_FG%}${POWERLINE_CHARS_SEPARATOR}%{%f%}"
}

# Function to get git status
function get_git_status() {
    if ! command -v git &> /dev/null; then
        return 1
    fi

    local git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [ -z "$git_dir" ]; then
        return 1
    fi

    local branch=$(git branch --show-current 2>/dev/null)
    if [ -z "$branch" ]; then
        return 1
    fi

    git diff --quiet --ignore-submodules HEAD 2>/dev/null
    local dirty_status=$?

    if [ "$dirty_status" -eq 1 ]; then
        echo "$branch|dirty"
    else
        echo "$branch|clean"
    fi
}

# Function to get runtime/language indicators
function get_runtime_indicator() {
    local indicators=()
    [[ -f "pyproject.toml" || -f "requirements.txt" || -f ".python-version" ]] && indicators+=("$POWERLINE_CHARS_PYTHON py")
    [[ -f "Cargo.toml" ]] && indicators+=("$POWERLINE_CHARS_RUST rs")
    [[ -f "package.json" ]] && indicators+=("$POWERLINE_CHARS_NODE js")
    [[ -f "Containerfile" || -f "podman-compose.yml" || -f "Dockerfile" ]] && indicators+=("$POWERLINE_CHARS_DOCKER podman")
    echo "${indicators[@]}"
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
    rprompt+="%{$POWERLINE_COLOR_TIME_FG%}🕐 $(date '+%H:%M:%S')%{%f%}"
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
    local runtime_indicators=($(get_runtime_indicator))
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
