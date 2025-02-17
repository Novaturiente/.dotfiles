set fish_greeting

source ~/.config/fish/cachyos-config.fish

zoxide init fish | source

alias vi="nvim"

set VISUAL "nvim"
set EDITOR "nvim"

alias winstart="docker compose --file ~/.config/winapps/compose.yaml start"
alias winstop="docker compose --file ~/.config/winapps/compose.yaml stop"
alias winrestart="docker compose --file ~/.config/winapps/compose.yaml restart"
# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
