#!/usr/bin/env bash

RECORDING_DIR="$(xdg-user-dir VIDEOS)/Screencasts"
PIDFILE="/tmp/wl-screenrec.pid"
MODFILE="/tmp/wl-screenrec.recmix-modules"

mkdir -p "$RECORDING_DIR"

getdate() {
    date '+%Y-%m-%d_%H.%M.%S'
}

# Mix system audio + mic into a null sink; record its monitor.
# ponytail: modules are torn down on stop and die with pipewire anyway, so no persistent config.
setup_mix() {
    pactl load-module module-null-sink sink_name=recmix \
        sink_properties=device.description=RecMix >"$MODFILE" || return 1
    pactl load-module module-loopback source="$(pactl get-default-sink).monitor" \
        sink=recmix latency_msec=20 >>"$MODFILE"
    pactl load-module module-loopback source="$(pactl get-default-source)" \
        sink=recmix latency_msec=20 >>"$MODFILE"
}

teardown_mix() {
    [ -f "$MODFILE" ] || return 0
    tac "$MODFILE" | xargs -r -n1 pactl unload-module
    rm -f "$MODFILE"
}

stop_recording() {
    if [ -f "$PIDFILE" ]; then
        pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill -INT "$pid"
            wait "$pid" 2>/dev/null
            rm -f "$PIDFILE"
            teardown_mix
            notify-send "Recording Stopped" "Saved to $RECORDING_DIR" -a 'wl-screenrec'
            return 0
        fi
        rm -f "$PIDFILE"
        teardown_mix
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
    --region-both)
        GEOMETRY=$(slurp)
        [ -z "$GEOMETRY" ] && exit 1
        setup_mix || exit 1
        notify-send "Recording Region + System + Mic" "$FILENAME" -a 'wl-screenrec'
        wl-screenrec -g "$GEOMETRY" --audio --audio-device recmix.monitor -f "$FILENAME" &
        ;;
    --fullscreen-both)
        setup_mix || exit 1
        notify-send "Recording Screen + System + Mic" "$FILENAME" -a 'wl-screenrec'
        wl-screenrec --audio --audio-device recmix.monitor -f "$FILENAME" &
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
