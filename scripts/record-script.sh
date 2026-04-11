#!/usr/bin/env bash

RECORDING_DIR="$(xdg-user-dir VIDEOS)/Screencasts"
PIDFILE="/tmp/wl-screenrec.pid"

mkdir -p "$RECORDING_DIR"

getdate() {
    date '+%Y-%m-%d_%H.%M.%S'
}

stop_recording() {
    if [ -f "$PIDFILE" ]; then
        pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill -INT "$pid"
            wait "$pid" 2>/dev/null
            rm -f "$PIDFILE"
            notify-send "Recording Stopped" "Saved to $RECORDING_DIR" -a 'wl-screenrec'
            return 0
        fi
        rm -f "$PIDFILE"
    fi
    return 1
}

# If already recording, stop it
if stop_recording; then
    exit 0
fi

FILENAME="$RECORDING_DIR/recording_$(getdate).mp4"

case "$1" in
    --region)
        GEOMETRY=$(slurp)
        [ -z "$GEOMETRY" ] && exit 1
        notify-send "Recording Region" "$FILENAME" -a 'wl-screenrec'
        wl-screenrec -g "$GEOMETRY" -f "$FILENAME" &
        ;;
    --region-audio)
        GEOMETRY=$(slurp)
        [ -z "$GEOMETRY" ] && exit 1
        notify-send "Recording Region + Audio" "$FILENAME" -a 'wl-screenrec'
        wl-screenrec -g "$GEOMETRY" --audio -f "$FILENAME" &
        ;;
    --fullscreen-audio)
        notify-send "Recording Screen + Audio" "$FILENAME" -a 'wl-screenrec'
        wl-screenrec --audio -f "$FILENAME" &
        ;;
    *)
        notify-send "Recording Screen" "$FILENAME" -a 'wl-screenrec'
        wl-screenrec -f "$FILENAME" &
        ;;
esac

echo $! > "$PIDFILE"
disown
