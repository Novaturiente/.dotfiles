#!/bin/bash

SESSION_NAME="default"
TMUX_CONF="$HOME/.tmux.conf"
PLUGINS_DIR="$HOME/.tmux/plugins"

load_tmux_plugins() {
    if [ -d "$PLUGINS_DIR/tpm" ]; then
        "$PLUGINS_DIR/tpm/bin/install_plugins" >/dev/null 2>&1
        tmux source-file "$TMUX_CONF" >/dev/null 2>&1
        sleep 1
        tmux refresh-client -S >/dev/null 2>&1
        
        [ -f "$PLUGINS_DIR/tmux-battery/scripts/battery.sh" ] && 
            "$PLUGINS_DIR/tmux-battery/scripts/battery.sh" >/dev/null 2>&1
        
        [ -f "$PLUGINS_DIR/tmux-cpu/scripts/cpu.sh" ] && 
            "$PLUGINS_DIR/tmux-cpu/scripts/cpu.sh" >/dev/null 2>&1
    fi
}

if [ -n "$TMUX" ]; then
    :
elif tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux attach -t "$SESSION_NAME"
else
    tmux -f "$TMUX_CONF" new-session -d -s "$SESSION_NAME"
    load_tmux_plugins &
    tmux attach -t "$SESSION_NAME"
fi
