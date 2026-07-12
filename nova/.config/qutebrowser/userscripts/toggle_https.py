#!/usr/bin/env python3
"""Toggle HTTPS-only enforcement for the current site.

Adds/removes the current host (with port, if any) in ~/.config/qutebrowser/
https_excludes, then re-sources the config so https_only.py picks it up.
Bound to <Space>th.
"""

import os
import sys
from urllib.parse import urlsplit

EXCLUDE_FILE = os.path.expanduser("~/.config/qutebrowser/https_excludes")
QUTE_FIFO = os.environ.get("QUTE_FIFO")
QUTE_URL = os.environ.get("QUTE_URL")


def send(command):
    if not QUTE_FIFO:
        print("QUTE_FIFO not set - run this from qutebrowser", file=sys.stderr)
        sys.exit(1)
    with open(QUTE_FIFO, "w") as f:
        f.write(command + "\n")


def main():
    if not QUTE_URL:
        send("message-error 'No URL for this page'")
        return

    # netloc keeps the port, which is the whole point for novahome:2283
    host = urlsplit(QUTE_URL).netloc
    if not host:
        send("message-error 'Could not parse host'")
        return

    hosts = []
    if os.path.exists(EXCLUDE_FILE):
        with open(EXCLUDE_FILE) as f:
            hosts = f.read().split()

    if host in hosts:
        hosts.remove(host)
        action = "enforced"
    else:
        hosts.append(host)
        action = "disabled"

    with open(EXCLUDE_FILE, "w") as f:
        f.write("\n".join(hosts) + ("\n" if hosts else ""))

    # config-source re-runs config.py, which re-reads the file and updates the
    # interceptor's exclude set in place.
    send("config-source")
    send(f"message-info 'HTTPS-only {action} for {host}'")

    if action == "disabled":
        # We are on the https:// page that failed; go back to the http:// one.
        send(f"open http://{host}{urlsplit(QUTE_URL).path}")


if __name__ == "__main__":
    main()
