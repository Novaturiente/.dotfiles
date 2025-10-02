#!/bin/bash

BOOKMARKS_FILE="$HOME/.dotfiles/.bookmarks"
BROWSER="qutebrowser"
export GDK_BACKEND=wayland

if [[ ! -a "${BOOKMARKS_FILE}" ]]; then
    touch "${BOOKMARKS_FILE}"
fi

if [ -n "$1" ]; then
    INPUT="$1"
    title=$(wget -qO- "$INPUT" | sed -n 's:.*<title>\(.*\)</title>.*:\1:p')
    if [[ -z "$title" ]]; then
        # Extract part between // and next /
        title=$(echo "$INPUT" | awk -F[/:] '{print $4}')
    fi
    echo "${title}=${INPUT}" >> "$BOOKMARKS_FILE"
else

    LIST=$(cut -d'=' -f1 "$BOOKMARKS_FILE")

    INPUT=$(echo "$LIST" | rofi -dmenu -theme black -p "")


    if [[ $INPUT == "+"* ]]; then
        INPUT="${INPUT#+}"
        title=$(wget -qO- "$INPUT" | sed -n 's:.*<title>\(.*\)</title>.*:\1:p')
        if [[ -z "$title" ]]; then
            # Extract part between // and next /
            title=$(echo "$INPUT" | awk -F[/:] '{print $4}')
        fi
        echo "${title}=${INPUT}" >> "$BOOKMARKS_FILE"

    elif [[ $INPUT == "-" ]]; then
        # Show bookmark list for removal
        SELECTED=$(rofi -dmenu -theme tokyonight -p "Remove bookmark" < "$BOOKMARKS_FILE")
        if [[ -n "$SELECTED" ]]; then
            sed -i "/^$(printf '%s' "$SELECTED" | sed 's/[]\/.^$*]/\\&/g')$/d" "$BOOKMARKS_FILE"
        fi

    elif [[ -z $INPUT ]]; then
        exit 0

    else
        # Escape special characters for sed
        LINK=$(grep "^${INPUT}=" "$BOOKMARKS_FILE" | cut -d'=' -f2-)
        LINE=$(grep "^${INPUT}=" "$BOOKMARKS_FILE")
        grep -Fvx "$LINE" "$BOOKMARKS_FILE" > temp && mv temp "$BOOKMARKS_FILE"
        sed -i "1i $LINE" "$BOOKMARKS_FILE"
        $BROWSER "$LINK"
    fi
fi
