#!/usr/bin/env bash

selection=$(
  fd --type f --hidden \
    --exclude .cache \
    --exclude .local \
    --exclude Games \
    --exclude .mozilla \
    --exclude .keras \
    --exclude .fltk \
    --exclude .npm \
    --exclude .nv \
    --exclude .deepface \
    --exclude .steam \
    --exclude .var \
    --exclude .pki \
    --exclude .zen \
    --exclude go \
    --exclude .cargo \
    . | fzf
)

if [ -n "$selection" ]; then
  tmux new-window "nvim \"$selection\""
fi
