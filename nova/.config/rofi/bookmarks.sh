#!/bin/bash

BOOKMARKS_FILE="$HOME/.dotfiles/.bookmarks"
BROWSER="qutebrowser"
export GDK_BACKEND=x11

if [[ ! -a "${BOOKMARKS_FILE}" ]]; then
    touch "${BOOKMARKS_FILE}"
fi

INPUT=$(rofi -dmenu -theme tokyonight -p "#B#" < "$BOOKMARKS_FILE")

if [[ $INPUT == "+"* ]]; then
    INPUT="${INPUT#+}"
    echo "$INPUT" >> "$BOOKMARKS_FILE"

elif [[ $INPUT == "_"* ]]; then
    INPUT="${INPUT#_}"
    # Escape special characters for sed
    ESCAPED_INPUT=$(printf '%s\n' "$INPUT" | sed 's/[][\\/.*^$]/\\&/g')
    sed -i "/^$ESCAPED_INPUT$/d" "$BOOKMARKS_FILE"

elif [[ $INPUT == *"."* || $INPUT == *"//"* ]]; then
    # Escape special characters for sed
    ESCAPED_INPUT=$(printf '%s\n' "$INPUT" | sed 's/[][\\/.*^$]/\\&/g')
    sed -i "/^$ESCAPED_INPUT$/d" "$BOOKMARKS_FILE" # Remove original
    sed -i "1i$INPUT" "$BOOKMARKS_FILE"            # Add to top
    $BROWSER "$INPUT"

elif [[ -z $INPUT ]]; then
    exit 0

else
    $BROWSER "https://www.google.com/search?q=$INPUT"
fi
