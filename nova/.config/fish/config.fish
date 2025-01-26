set fish_greeting

source ~/.config/fish/cachyos-config.fish

zoxide init fish | source

alias vi="nvim"

set VISUAL "nvim"
set EDITOR "nvim"

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
