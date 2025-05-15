set fish_greeting

source ~/.config/fish/cachyos-config.fish

source ~/.env.fish

zoxide init fish | source

alias vi="nvim"

set VISUAL "nvim"
set EDITOR "nvim"

alias systemupdate="sudo akshara update && reboot"
alias cp='rsync -avP --progress'
alias mv='rsync -avP --remove-source-files --progress'

set NVIM_LOG_FILE "$HOME/.cache/nvim/my_custom_log.txt"

set -U fish_user_paths ~/.npm-global/bin $fish_user_paths

