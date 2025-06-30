# Zsh Prompt Configuration

# Disable virtualenv prompt modification
VIRTUAL_ENV_DISABLE_PROMPT=1

# --- Characters (requires a Nerd Font) ---
POWERLINE_CHARS_SEPARATOR=""
POWERLINE_CHARS_BRANCH=""
POWERLINE_CHARS_HOME="🐧"
POWERLINE_CHARS_FOLDER="📁"
POWERLINE_CHARS_DOWNLOADS="📥"
POWERLINE_CHARS_DEV="💻"
POWERLINE_CHARS_TEMP="🧹"
POWERLINE_CHARS_GIT=""
POWERLINE_CHARS_PYTHON=""
POWERLINE_CHARS_RUST=""
POWERLINE_CHARS_NODE="󰎙"
POWERLINE_CHARS_DOCKER="🐳"
POWERLINE_CHARS_CONFIG="🛠️"

# --- Color Scheme (Foreground colors only) ---
POWERLINE_COLOR_USER_FG="%F{#007ACC}"
POWERLINE_COLOR_PATH_FG="%F{#CCCCCC}"
POWERLINE_COLOR_GIT_FG="%F{#8FBC8F}"
POWERLINE_COLOR_GIT_DIRTY_FG="%F{#FF6B6B}"
POWERLINE_COLOR_TIME_FG="%F{#6A5ACD}"
POWERLINE_COLOR_STATUS_FG="%F{#32CD32}"
POWERLINE_COLOR_ERROR_FG="%F{#FF4500}"
POWERLINE_COLOR_SEPARATOR_FG="%F{#666666}"

# --- Helper Functions ---

# Function to create a styled segment
function make_segment() {
    local content="$1"
    local fg_color="$2"
    echo -n "%{$fg_color%}$content%{%f%}"
    echo -n "%{$POWERLINE_COLOR_SEPARATOR_FG%}$POWERLINE_CHARS_SEPARATOR%{%f%}"
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
    local is_dirty=$(git status --porcelain=v1 2>/dev/null)

    if [ -z "$branch" ]; then
        return 1
    fi

    if [ -n "$is_dirty" ]; then
        echo "$branch dirty"
    else
        echo "$branch clean"
    fi
}

# Function to get runtime/language indicators
function get_runtime_indicator() {
    local indicators=()
    if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ] || [ -f ".python-version" ]; then
        indicators+=("$POWERLINE_CHARS_PYTHON py")
    fi
    if [ -f "Cargo.toml" ]; then
        indicators+=("$POWERLINE_CHARS_RUST rs")
    fi
    if [ -f "package.json" ]; then
        indicators+=("$POWERLINE_CHARS_NODE js")
    fi
    if [ -f "Containerfile" ] || [ -f "podman-compose.yml" ] || [ -f "Dockerfile" ]; then
        indicators+=("$POWERLINE_CHARS_DOCKER podman")
    fi

    if [ ${#indicators[@]} -gt 0 ]; then
        echo "${indicators[@]}"
    fi
}

# --- Main Prompt Functions ---

# Right-side prompt (Time)
function right_prompt() {
    if [ -n "$VIRTUAL_ENV" ]; then
        local venv_name=$(basename $(dirname $VIRTUAL_ENV))
        local py_version=$(python -c "import platform; print(platform.python_version())" 2>/dev/null)
        echo -n "%{$POWERLINE_COLOR_STATUS_FG%}($venv_name; $py_version) %{%f%}"
    fi

    echo -n "%{$POWERLINE_COLOR_TIME_FG%}🕐 $(date '+%H:%M:%S')%{%f%}"
}

# Main prompt function (Left-side)
function set_prompt() {
    local last_status=$?

    # User segment
    make_segment "$USER" "$POWERLINE_COLOR_USER_FG"

    # Path segment
    local path_display=$(print -P %~)
    local path_icon=$POWERLINE_CHARS_FOLDER
    if [[ $path_display == "~" ]]; then
        path_icon=$POWERLINE_CHARS_HOME
    elif [[ $path_display == "~/develop" ]]; then
        path_icon=$POWERLINE_CHARS_DEV
    elif [[ $path_display == "~/Downloads" ]]; then
        path_icon=$POWERLINE_CHARS_DOWNLOADS
    elif [[ $path_display == "~/temp" ]]; then
        path_icon=$POWERLINE_CHARS_TEMP
    elif [[ $path_display == "~/.dotfiles" || $path_display == "~/dotfiles" ]]; then
        path_icon=$POWERLINE_CHARS_CONFIG
    fi
    make_segment " $path_icon $path_display" "$POWERLINE_COLOR_PATH_FG"

    # Git segment
    local git_status=($(get_git_status))
    if [ -n "$git_status" ]; then
        local branch=$git_status[1]
        local state=$git_status[2]
        local git_color=$POWERLINE_COLOR_GIT_FG
        local git_icon=$POWERLINE_CHARS_GIT
        
        if [ "$state" = "dirty" ]; then
            git_color=$POWERLINE_COLOR_GIT_DIRTY_FG
        fi

        if [ -n "$git_icon" ]; then
            make_segment " $git_icon $branch" "$git_color"
        else
            make_segment " $branch" "$git_color"
        fi
    fi

    # Runtime/Language segment
    local runtime=($(get_runtime_indicator))
    if [ -n "$runtime" ]; then
        make_segment " $runtime" "$POWERLINE_COLOR_STATUS_FG"
    fi

    # Newline for the second line of the prompt
    echo ""

    # Prompt indicator
    if [ $last_status -eq 0 ]; then
        echo -n "❯ "
    else
        echo -n "%{$POWERLINE_COLOR_ERROR_FG%}❯ %{%f%}"
    fi
}

# Set the prompts
autoload -Uz add-zsh-hook
add-zsh-hook precmd update_prompt

function update_prompt() {
    PROMPT=$(set_prompt)
    RPROMPT=$(right_prompt)
}

# Initialize prompt
update_prompt

# Vi mode indicator (requires proper key bindings setup)
function zle-line-init zle-keymap-select {
    case $KEYMAP in
        vicmd) PROMPT=${PROMPT//❯/❮} ;;
        *) PROMPT=${PROMPT//❮/❯} ;;
    esac
    zle reset-prompt
}
zle -N zle-line-init
zle -N zle-keymap-select
