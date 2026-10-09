#!/usr/bin/env python3
"""Teach-mode lesson server.

Serves /tmp/teach-lessons/<topic>/lesson.html wrapped in assets/lesson-template.html,
and saves answers POSTed by the page's Submit button to <topic>/answers.json.
Prints "SUBMITTED <topic> <path>" on every submit so a process-tool log watch wakes the agent.

Usage: lesson_server.py [port]    (default 8765, binds 127.0.0.1 only)
"""
import json
import os
import re
import sys
from datetime import datetime
from html import escape
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# User-chosen path; secure_root() refuses it unless it is our own real dir, then locks it to 0700.
ROOT = Path("/tmp/teach-lessons")  # noqa: S108  # nosec B108
TEMPLATE = Path(__file__).resolve().parent.parent / "assets" / "lesson-template.html"
ROUTE = re.compile(r"^/([a-z0-9][a-z0-9-]{0,63})(/|/submit)?$")
MAX_BODY = 1_000_000


def secure_root():
    try:
        ROOT.mkdir(mode=0o700, exist_ok=True)
        st = os.lstat(ROOT)  # lstat: a planted symlink must not pass
        ok = os.path.isdir(ROOT) and not os.path.islink(ROOT) and st.st_uid == os.getuid()
        if ok:
            os.chmod(ROOT, 0o700)
    except OSError as e:
        sys.exit(f"Cannot use {ROOT}: {e}")
    if not ok:
        sys.exit(f"Refusing {ROOT}: not a real directory owned by you. Remove it and retry.")


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body, ctype="text/html; charset=utf-8", location=None):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        if location:
            self.send_header("Location", location)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/":
            links = "".join(
                f'<li><a href="/{escape(p.parent.name)}/">{escape(p.parent.name)}</a></li>'
                for p in sorted(ROOT.glob("*/lesson.html"))
            )
            return self.send(200, f"<h1>Lessons</h1><ul>{links or '<li>none yet</li>'}</ul>")
        m = ROUTE.match(path)
        if not m or m[2] == "/submit":
            return self.send(404, "Not found")
        if m[2] is None:  # relative "submit" URL in the page needs the trailing slash
            return self.send(301, "", location=f"/{m[1]}/")
        lesson = ROOT / m[1] / "lesson.html"
        if not lesson.is_file():
            return self.send(404, f"No lesson at {escape(str(lesson))}")
        # Read both per request so edits show on refresh.
        self.send(200, TEMPLATE.read_text().replace("<!--LESSON-->", lesson.read_text(), 1))

    def do_POST(self):
        m = ROUTE.match(self.path)
        if not m or m[2] != "/submit":
            return self.send(404, "Not found")
        # JSON content type forces a CORS preflight, so other websites cannot post here.
        if not self.headers.get("Content-Type", "").startswith("application/json"):
            return self.send(415, "Expected application/json")
        try:
            n = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            n = 0
        if not 0 < n <= MAX_BODY:
            return self.send(413, "Body missing or too large")
        try:
            data = json.loads(self.rfile.read(n))
        except ValueError:
            return self.send(400, "Bad JSON")
        out = ROOT / m[1] / "answers.json"
        if not isinstance(data, dict) or not out.parent.is_dir():
            return self.send(400, "Bad submission")
        data["receivedAt"] = datetime.now().isoformat(timespec="seconds")
        out.write_text(json.dumps(data, indent=2))
        print(f"SUBMITTED {m[1]} {out}", flush=True)
        self.send(200, '{"ok": true}', "application/json")

    def log_message(self, format, *args):  # noqa: A002 - must match base signature
        pass  # keep stdout for the SUBMITTED lines the agent watches


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    secure_root()
    print(f"Lesson server on http://127.0.0.1:{port}/", flush=True)
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
