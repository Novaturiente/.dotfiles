#!/usr/bin/env python3
"""Toggle a transparent (compositor-blurred) background for the current site.

transparent_sites is the source of truth; this rewrites the HOSTS line of
greasemonkey/transparent.js from it, then reloads. Bound to <Space>tb.

Greasemonkey rather than content.user_stylesheets because that setting takes no
URL pattern - it applies to every site or none.
"""

import json
import os
import re
import sys
from urllib.parse import urlsplit

CONFDIR = os.path.expanduser("~/.config/qutebrowser")
SITE_FILE = os.path.join(CONFDIR, "transparent_sites")
GM_FILE = os.path.join(CONFDIR, "greasemonkey", "transparent.js")
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

    # netloc keeps the port, so novahome:2283 is a distinct site
    host = urlsplit(QUTE_URL).netloc
    if not host:
        send("message-error 'Could not parse host'")
        return

    hosts = []
    if os.path.exists(SITE_FILE):
        with open(SITE_FILE) as f:
            hosts = f.read().split()

    if host in hosts:
        hosts.remove(host)
        action = "opaque"
    else:
        hosts.append(host)
        action = "transparent"

    with open(SITE_FILE, "w") as f:
        f.write("\n".join(hosts) + ("\n" if hosts else ""))

    with open(GM_FILE) as f:
        script = f.read()
    script, n = re.subn(
        r"^const HOSTS = .*$",
        "const HOSTS = " + json.dumps(hosts) + ";",
        script,
        count=1,
        flags=re.MULTILINE,
    )
    if not n:
        send("message-error 'No HOSTS line in transparent.js'")
        return
    with open(GM_FILE, "w") as f:
        f.write(script)

    send("greasemonkey-reload")
    send(f"message-info 'Background {action} for {host}'")
    send("reload")


if __name__ == "__main__":
    main()
