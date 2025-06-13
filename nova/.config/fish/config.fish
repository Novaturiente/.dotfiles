set fish_greeting

if test -f ~/.env.fish
  source ~/.env.fish
end

zoxide init fish | source

alias vi="nvim"

set VISUAL "nvim"
set EDITOR "nvim"

alias systemupdate="sudo akshara update && reboot"
# alias cp='rsync -avP --progress'
# alias mv='rsync -avP --remove-source-files --progress'

set NVIM_LOG_FILE "$HOME/.cache/nvim/my_custom_log.txt"

set -U fish_user_paths ~/.npm-global/bin $fish_user_paths

## Source from conf.d before our fish config
source ~/.config/fish/done.fish

# Format man pages
set -x MANROFFOPT "-c"
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

# Set settings for https://github.com/franciscolourenco/done
set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

# Add ~/.local/bin to PATH
if test -d ~/.local/bin
    if not contains -- ~/.local/bin $PATH
        set -p PATH ~/.local/bin
    end
end

# Add depot_tools to PATH
if test -d ~/Applications/depot_tools
    if not contains -- ~/Applications/depot_tools $PATH
        set -p PATH ~/Applications/depot_tools
    end
end

# Fish command history
function history
    builtin history --show-time='%F %T '
end

function backup --argument filename
    cp $filename $filename.bak
end

## Useful aliases
# Replace ls with eza
alias ls='eza -a --color=always --group-directories-first --icons' # preferred listing
alias la='eza -al --color=always --group-directories-first --icons'  # all files and dirs
alias ll='eza -l --color=always --group-directories-first --icons'  # long format
alias lt='eza -aT --color=always --group-directories-first --icons' # tree listing
alias l.="eza -a | grep -e '^\.'"                                     # show only dotfiles

# Common use
alias grubup="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Get the error messages from journalctl
alias jctl="journalctl -p 3 -xb"

alias winconnect="com.freerdp.FreeRDP /v:127.0.0.1 /u:Docker /p:novarch /dynamic-resolution /sound"

alias ollama="podman exec -it ollama ollama"
alias ollamaup="podman-compose -f ~/.dotfiles/podman/ollama.yml up -d"
alias ollamadown="podman-compose -f ~/.dotfiles/podman/ollama.yml down"

source ~/.config/fish/prompt.fish
