#!/usr/bin/env bash

FOLDER_ICON="󰙅" #
FILE_ICON="󱓧"   #

exclude_folders=(.git node_modules .cache .local cache *Brave* go emacs data Games .venv .cargo .android .aider .floorp .histdb .mozilla .mullvad .npm .nv .pki .rustup .ssh .fonts Torrent)

exclude_args=()
for folder in "${exclude_folders[@]}"; do
    exclude_args+=(--exclude "$folder")
done

copy_move() {
    SOURCE_ENTRIES=$(fd --type f --type d --hidden --follow . "$HOME" "${exclude_args[@]}" \
        --exec stat --format="%Y %n" {} \; | \
        sort -nr | \
        cut -d' ' -f2- | \
        while read -r path; do
            if [[ -d "$path" ]]; then
                echo "${FOLDER_ICON} $path"
            else
                echo "${FILE_ICON} $path"
            fi
        done)

    SOURCE=$(echo "$SOURCE_ENTRIES" | rofi -dmenu -i -p "󰆏 SELECT " -theme "black.rasi")

    [[ -z "$SOURCE" ]] && exit 0

    SOURCE="${SOURCE:2}"

    DEST_ENTRIES=$(
        fd --type f --type d --hidden --follow . "$HOME" "${exclude_args[@]}" |
            while read -r path; do
                # Get modification time as epoch seconds
                mtime=$(stat --format="%Y" "$path")
                echo "$mtime $path"
            done |
            sort -nr |
            cut -d' ' -f2- |
            while read -r path; do
                if [[ -d "$path" ]]; then
                    echo "${FOLDER_ICON} $path"
                fi
            done
    )

    DEST_FOLDER=$(echo "$DEST_ENTRIES" | rofi -dmenu -i -p " SELECT FOLDER " -theme "black.rasi")

    DEST_FOLDER="${DEST_FOLDER:2}"

    BASENAME=$(basename -- "$SOURCE")

    FILENAME=$(rofi -dmenu -i -p " FILE NAME " -filter "$BASENAME")

    if [[ -z "$FILENAME" ]]; then
        DESTINATION="${DEST_FOLDER}"
    else
        DESTINATION="${DEST_FOLDER}${FILENAME}"
    fi

    if [[ "$1" == "copy" ]]; then
        echo "Copy $SOURCE to $DESTINATION"
        cp -r "$SOURCE" "$DESTINATION"
    elif [[ "$1" == "move" ]]; then
        echo "Move $SOURCE to $DESTINATION"
        mv "$SOURCE" "$DESTINATION"
    else
        echo "No valid argument"
    fi
}

rename() {
    SOURCE_ENTRIES=$(fd --type f --type d --hidden --follow . "$HOME" "${exclude_args[@]}" \
        --exec stat --format="%Y %n" {} \; | \
        sort -nr | \
        cut -d' ' -f2- | \
        while read -r path; do
            if [[ -d "$path" ]]; then
                echo "${FOLDER_ICON} $path"
            else
                echo "${FILE_ICON} $path"
            fi
        done)

    SOURCE=$(echo "$SOURCE_ENTRIES" | rofi -dmenu -i -p "󰆏 SELECT " -theme "black.rasi")

    [[ -z "$SOURCE" ]] && exit 0

    SOURCE="${SOURCE:2}"

    BASENAME=$(basename -- "$SOURCE")
    BASEFOLDER=$(dirname -- "$SOURCE")

    FILENAME=$(rofi -dmenu -i -p " NEW FILE NAME " -filter "$BASENAME")

    DESTINATION="${BASEFOLDER}/${FILENAME}"

    echo "Renaming $SOURCE to $DESTINATION"
    mv "$SOURCE" "$DESTINATION"
}

delete() {
    SOURCE_ENTRIES=$(fd --type f --type d --hidden --follow . "$HOME" "${exclude_args[@]}" \
        --exec stat --format="%Y %n" {} \; | \
        sort -nr | \
        cut -d' ' -f2- | \
        while read -r path; do
            if [[ -d "$path" ]]; then
                echo "${FOLDER_ICON} $path"
            else
                echo "${FILE_ICON} $path"
            fi
        done)

    SOURCE=$(echo "$SOURCE_ENTRIES" | rofi -dmenu -i -p "󰆏 SELECT " -theme "black.rasi")

    [[ -z "$SOURCE" ]] && exit 0

    SOURCE="${SOURCE:2}"

    CONFIRM=$(printf " Yes\n No" | rofi -dmenu -i -p "󰆴 Delete : $SOURCE ?" -theme "black.rasi")

    if [[ "$CONFIRM" == " Yes" ]]; then
        trash-put "$SOURCE"
    else
        exit 0
    fi
}

restore() {
    mapfile -t files < <(trash-list | sort -k1,2r | awk '{print $1 " " substr($0, index($0,$2))}')

    SOURCE=$(printf '%s\n' "${files[@]}" | cut -d' ' -f3- | rofi -dmenu -i -p "󰆏 SELECT " -theme "black.rasi")

    [[ -z "$SOURCE" ]] && exit 0

    echo "$SOURCE"
    printf "0\n" | trash-restore "$SOURCE"
}

declare -A tools=(
    [" Copy"]="copy_move copy"
    ["󰪹 Move"]="copy_move move"
    [" Rename"]="rename "
    ["󰗨 Delete"]="delete "
    ["󱀸 Recover"]="restore "
)

selected_key=$(printf "%s\n" "${!tools[@]}" | rofi -dmenu -p "Select :" -theme power)

if [[ -n $selected_key && -n ${tools[$selected_key]} ]]; then
    read -r func arg <<<"${tools[$selected_key]}"
    # func="${tools[$selected_key]}"
    $func "$arg"
fi
