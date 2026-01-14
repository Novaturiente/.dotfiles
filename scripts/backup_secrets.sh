#!/usr/bin/env bash

# Set valid source paths based on what exists
SOURCES=""
[ -d "$HOME/.ssh" ] && SOURCES="$SOURCES $HOME/.ssh"
[ -d "$HOME/.gnupg" ] && SOURCES="$SOURCES $HOME/.gnupg"

if [ -z "$SOURCES" ]; then
    echo "Error: Neither ~/.ssh nor ~/.gnupg found."
    exit 1
fi

DEST="$HOME/.dotfiles/secrets.7z"

echo "Creating encrypted backup of:"
for s in $SOURCES; do echo "  - $s"; done
echo "Destination: $DEST"
echo ""
echo "Security Note: Using AES-256 encryption. Choose a STRONG password."
echo "You will be prompted for the password twice."

# 7z a (add) 
# -t7z (7z format)
# -mhe=on (encrypt header/filenames)
# -p (prompt for password)
# -mx=9 (ultra compression)
7z a -t7z -mhe=on -p -mx=9 "$DEST" $SOURCES

chmod 600 "$DEST"
echo ""
echo "Backup complete: $DEST"
echo "To restore: 7z x secrets.7z -o$HOME"
