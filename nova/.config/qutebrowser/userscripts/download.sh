#!/usr/bin/env bash

notify-send "Download added"
/home/nova/.local/bin/aria2p add "$1"
