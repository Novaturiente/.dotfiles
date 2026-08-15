#!/usr/bin/env bash
# nixos-console.sh - drive the NixOS VM's serial console from the host.
#   nixos-console.sh                 read whatever is on the console now
#   nixos-console.sh 'ls -la /etc'   send a line, print what comes back
#   echo 'text' | nixos-console.sh - send stdin verbatim (heredocs, file writes)
# Needs the VM running via scripts/nixos-vm.sh and the guest booted with
# console=ttyS0,115200 so a getty is listening.
# Env: VM_SERIAL_PORT (default 4445), IDLE (seconds of silence = done, default 1.5)
set -euo pipefail

PORT=${VM_SERIAL_PORT:-4445}
IDLE=${IDLE:-1.5}

if [[ ${1:-} == - ]]; then
	PAYLOAD=$(cat)
elif [[ $# -gt 0 ]]; then
	PAYLOAD=$1
else
	PAYLOAD=""
fi

PORT=$PORT IDLE=$IDLE PAYLOAD=$PAYLOAD python3 - <<'PY'
import os, socket, sys, time

port = int(os.environ["PORT"])
idle = float(os.environ["IDLE"])
payload = os.environ["PAYLOAD"]

s = socket.create_connection(("127.0.0.1", port), timeout=5)
s.settimeout(0.3)

# ponytail: drain stale output first so the reply isn't mixed with old scrollback.
# NODRAIN=1 keeps it — needed when polling a long command already in flight.
if not os.environ.get("NODRAIN"):
    while True:
        try:
            if not s.recv(65536):
                break
        except socket.timeout:
            break

if payload:
    s.sendall((payload.rstrip("\n") + "\n").encode())
else:
    s.sendall(b"\n")

out = bytearray()
last = time.time()
deadline = time.time() + 900          # hard cap: nixos-rebuild can be slow
while time.time() < deadline:
    try:
        chunk = s.recv(65536)
        if not chunk:
            break
        out += chunk
        last = time.time()
    except socket.timeout:
        if time.time() - last > idle:
            break
s.close()
sys.stdout.write(out.decode("utf-8", "replace"))
PY
