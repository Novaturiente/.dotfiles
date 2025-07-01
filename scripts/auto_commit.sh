#!/bin/bash

# echo ~/.local/share/fish/fish_history | entr sh -c '
#     cd ~/.dotfiles
#     git add .
#     git commit -m "update"
# '
echo ~/.zsh/.histfile | entr sh -c '
    cd ~/.dotfiles
    git add .
    git commit -m "update"
'
