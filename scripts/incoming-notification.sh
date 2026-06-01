#!/usr/bin/env bash
curl -sN https://ntfy.sh/eecglobal-deployments-yourprivateid/json | jq --unbuffered -r '.message' | while read -r msg; do [ -n "$msg" ] && notify-send "Deployment Alert" "$msg" --icon=dialog-error; done
