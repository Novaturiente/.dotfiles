#!/bin/bash

# echo ~/.local/share/fish/fish_history | entr sh -c '
#     cd ~/.dotfiles
#     git add .
#     git commit -m "update"
# '
echo $XDG_CONFIG_HOME/zsh/.histfile | entr sh -c '
    cd ~/.dotfiles
    git add .
    git commit -m "update"
'
