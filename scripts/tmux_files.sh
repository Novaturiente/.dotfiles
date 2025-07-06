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
    --exclude Docker \
    --exclude .themes \
    --exclude .fonts \
    . | fzf
)

if [ -n "$selection" ]; then
  nvim "$selection"
fi
