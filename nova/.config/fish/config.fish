set fish_greeting

source ~/.config/fish/cachyos-config.fish

zoxide init fish | source

alias vi="nvim"

set VISUAL "nvim"
set EDITOR "nvim"

alias systemupdate="sudo akshara update && reboot"

set NVIM_LOG_FILE "$HOME/.cache/nvim/my_custom_log.txt"
