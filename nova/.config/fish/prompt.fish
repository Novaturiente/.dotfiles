# Fish Shell Theme Configuration

set -gx VIRTUAL_ENV_DISABLE_PROMPT 1

# --- Characters (requires a Nerd Font) ---
set -g powerline_chars_separator ""
set -g powerline_chars_branch ""
set -g powerline_chars_home "🐧"
set -g powerline_chars_folder "📁"
set -g powerline_chars_git ""
set -g powerline_chars_python ""
set -g powerline_chars_rust ""
set -g powerline_chars_node "󰎙"
set -g powerline_chars_docker "🐳"

# --- Color Scheme (Foreground colors only) ---
set -g powerline_color_user_fg "#007ACC"
set -g powerline_color_path_fg "#CCCCCC"
set -g powerline_color_git_fg "#8FBC8F"
set -g powerline_color_git_dirty_fg "#FF6B6B"
set -g powerline_color_time_fg "#6A5ACD"
set -g powerline_color_status_fg "#32CD32"
set -g powerline_color_error_fg "#FF4500"
set -g powerline_color_separator_fg "#666666"

# --- Helper Functions ---

# Function to create a styled segment
function make_segment
    set -l content $argv[1]
    set -l fg_color $argv[2]
    set_color $fg_color
    echo -n "$content"
    set_color normal
    set_color $powerline_color_separator_fg
    echo -n "$powerline_chars_separator"
    set_color normal
end

# Function to get git status
function get_git_status
    if not command -q git
        return 1
    end

    set -l git_dir (git rev-parse --git-dir 2>/dev/null)
    if test -z "$git_dir"
        return 1
    end

    set -l branch (git branch --show-current 2>/dev/null)
    set -l is_dirty (git status --porcelain=v1 2>/dev/null)

    if test -z "$branch"
        return 1
    end

    if test -n "$is_dirty"
        echo "$branch" "dirty"
    else
        echo "$branch" "clean"
    end
end

# Function to get runtime/language indicators
function get_runtime_indicator
    set -l indicators
    if test -f "pyproject.toml" -o -f "requirements.txt" -o -f ".python-version"
        set -a indicators "$powerline_chars_python py"
    end
    if test -f "Cargo.toml"
        set -a indicators "$powerline_chars_rust rs"
    end
    if test -f "package.json"
        set -a indicators "$powerline_chars_node js"
    end
    if test -f "Containerfile" -o -f "podman-compose.yml" -o -f "Dockerfile"
      set -a indicators "$powerline_chars_docker podman"
    end

    if test (count $indicators) -gt 0
        echo (string join " " $indicators)
    end
end

# --- Main Prompt Functions ---

# Right-side prompt (Time)
function fish_right_prompt
    if set -q VIRTUAL_ENV
        set -l venv_name (basename (dirname $VIRTUAL_ENV))
        set -l py_version (python -c "import platform; print(platform.python_version())" 2>/dev/null)
        set_color $powerline_color_status_fg
        echo -n "($venv_name; $py_version) "
        set_color normal
    end

    set_color $powerline_color_time_fg
    echo -n "🕐 "(date '+%H:%M:%S')
    set_color normal
end

# Main prompt function (Left-side)
function fish_prompt
    set -l last_status $status

    # User segment
    make_segment "$USER" $powerline_color_user_fg

    # Path segment
    set -l path_display (prompt_pwd)
    set -l path_icon $powerline_chars_folder
    if string match -q "~*" "$path_display"
        set path_icon $powerline_chars_home
    end
    make_segment "$path_icon $path_display" $powerline_color_path_fg

    # Git segment
    set -l git_status (get_git_status)
    if test -n "$git_status"
        set -l branch (echo $git_status | cut -d' ' -f1)
        set -l state (echo $git_status | cut -d' ' -f2)
        set -l git_color $powerline_color_git_fg
        
        # The git_icon is empty by default, matching the original config.
        # The '±' symbol which previously indicated a dirty repo has been removed as requested.
        set -l git_icon "$powerline_chars_git" 
        
        if test "$state" = "dirty"
            set git_color $powerline_color_git_dirty_fg
        end

        # Display the git segment. This logic prevents a leading space if the icon is empty.
        if test -n "$git_icon"
            make_segment " $git_icon $branch" $git_color
        else
            make_segment " $branch" $git_color
        end
    end

    # Runtime/Language segment
    set -l runtime (get_runtime_indicator)
    if test -n "$runtime"
        make_segment " $runtime" $powerline_color_status_fg
    end

    # Newline for the second line of the prompt
    echo ""

    # Prompt indicator
    if test $last_status -eq 0
      echo -n "❯ "
    else
      set_color $powerline_color_error_fg
      echo -n "❯ "
      set_color normal
    end
end

# --- Prompt Indicators for different modes ---
# You might need to configure key bindings for Vi mode indicators to work effectively.
function fish_mode_prompt
    switch $fish_key_bindings
        case fish_vi_key_bindings
            echo -n "❮ "
        case default
            echo -n "❯ "
    end
end

set -g fish_greeting ""
