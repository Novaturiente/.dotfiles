#!/usr/bin/env python3
"""Git-aware file tree, runs inside the pane file-tree.sh opens on the right.

Root = git top folder of the window's agent folder (@agent_cwd), else of the
first ordinary pane, so a worktree shows the worktree. Folders open only along
the paths to changed files (git status); one you open or close by hand stays
that way until a new change appears inside it. Committed = folds away again.
Keys: j/k move, l/h open/close, enter open (file: nvim popup), d diff popup,
r paste @path into the agent, a changed-only view, g/G top/bottom, c collapse
all, e default view (only the paths to changes open), q close.
"""
import os
import re
import select
import shlex
import subprocess as sp
import sys
import termios
import time
import tty

PANE = os.environ.get("TMUX_PANE", "")
AGENTS = ("agy", "claude", "pi", "codex")
# Catppuccin Mocha
C = {"M": "249;226;175", "A": "166;227;161", "?": "166;227;161", "D": "243;139;168",
     "R": "137;180;250", "U": "243;139;168", "dir": "137;180;250", "text": "205;214;244",
     "dim": "108;112;134", "add": "166;227;161", "del": "243;139;168"}
SEL_BG = "\x1b[48;2;49;50;68m"
OFF = "\x1b[0m"

# Icons (Nerd Font glyphs, all checked in ZedMono Nerd Font). ICONS = False hides
# them. Add a type: extension (lower case) or exact file name -> (glyph, colour).
ICONS = True
Y, B, S, G, P, R, X, GREY = ("249;226;175", "137;180;250", "137;220;235", "166;227;161",
                          "250;179;135", "243;139;168", "205;214;244", "147;153;178")
FOLDER = ("\ue5ff", "\ue5fe")  # closed, open
FILE = ("\uf15b", GREY)  # no match
CONFIG, IMAGE, SHELL = ("\ue615", GREY), ("\ue60d", P), ("\ue691", G)
EXT = {
    "py": ("\ue606", Y), "js": ("\ue60c", Y), "mjs": ("\ue60c", Y), "cjs": ("\ue60c", Y),
    "ts": ("\ue628", B), "tsx": ("\ue625", S), "jsx": ("\ue625", S), "json": ("\U000f0626", Y),
    "md": ("\ue609", X), "txt": ("\ue64e", X), "sh": SHELL, "bash": SHELL, "zsh": SHELL,
    "fish": SHELL, "lua": ("\ue620", B), "rs": ("\ue68b", P), "go": ("\ue627", S),
    "html": ("\ue60e", P), "css": ("\ue614", B), "scss": ("\ue603", R), "sass": ("\ue603", R),
    "yml": ("\ue6a8", R), "yaml": ("\ue6a8", R), "toml": CONFIG, "ini": CONFIG, "conf": CONFIG,
    "kdl": CONFIG, "xml": ("\ue619", P), "c": ("\ue649", B), "h": ("\ue649", B),
    "cpp": ("\ue646", B), "java": ("\ue66d", R), "kt": ("\ue634", P), "rb": ("\ue605", R),
    "php": ("\ue608", B), "swift": ("\ue699", P), "vue": ("\ue6a0", G), "svelte": ("\ue697", P),
    "nix": ("\U000f1105", B), "vim": ("\ue62b", G), "sql": ("\ue64d", X), "db": ("\ue64d", X),
    "csv": ("\ue64a", G), "pdf": ("\ue67d", R), "zip": ("\ue6aa", Y), "gz": ("\ue6aa", Y),
    "tar": ("\ue6aa", Y), "svg": ("\ue698", Y), "png": IMAGE, "jpg": IMAGE, "jpeg": IMAGE,
    "gif": IMAGE, "webp": IMAGE, "ico": IMAGE, "mp4": ("\ue69f", P), "mp3": ("\ue638", S),
    "lock": ("\ue672", GREY),
}
NAMES = {
    "Makefile": ("\ue673", P), "Dockerfile": ("\ue650", B), "LICENSE": ("\ue60a", Y),
    ".gitignore": ("\ue702", P), ".gitattributes": ("\ue702", P), ".gitmodules": ("\ue702", P),
    "package-lock.json": ("\ue672", GREY), "tsconfig.json": ("\ue69d", B),
}


def icon(name, folder=False, opened=False):
    """Coloured glyph + space, or '' with icons off. Every glyph is 1 cell (Nerd Font Mono)."""
    if not ICONS:
        return "", 0
    if folder:
        g, c = FOLDER[opened], B
    else:
        g, c = NAMES.get(name) or EXT.get(name.rsplit(".", 1)[-1].lower() if "." in name else "", FILE)
    return f"\x1b[38;2;{c}m{g} ", 2


def fg(name):
    return f"\x1b[38;2;{C[name]}m"


def run(*a):
    r = sp.run(a, capture_output=True)
    return r.stdout.decode(errors="replace") if r.returncode == 0 else None


def tmux(*a):
    return run("tmux", *a) or ""


_top = {}


def toplevel(d):
    if d not in _top:
        _top[d] = (run("git", "-C", d, "rev-parse", "--show-toplevel") or "").strip() or None
    return _top[d]


def window():
    """(root, agent pane, agent folder, pane count) for the tree's window."""
    rows = [row.split("\t") for row in tmux(
        "list-panes", "-t", PANE, "-F",
        "#{pane_id}\t#{@agent}\t#{@agent_cwd}\t#{pane_current_path}\t#{@sidebar}#{@filetree}\t#{pane_current_command}",
    ).splitlines()]
    plain = [r for r in rows if len(r) == 6 and not r[4]]
    agents = [r for r in plain if r[1] or r[5] in AGENTS]
    pick = agents[0] if agents else (plain[0] if plain else None)
    cwd = (pick[2] or pick[3]) if pick else None
    return (toplevel(cwd) if cwd else None), (agents[0][0] if agents else None), cwd, len(rows)


def status(root):
    """path -> one status letter, from git status -z (renames: new path)."""
    out, d = run("git", "-C", root, "status", "--porcelain=v1", "-z", "-uall") or "", {}
    parts, i = out.split("\0"), 0
    while i < len(parts):
        e = parts[i]
        i += 1
        if len(e) < 4:
            continue
        xy, p = e[:2], e[3:]
        if xy[0] in "RC":
            i += 1  # -z puts the old name in the next field
        st = "?" if xy == "??" else (xy[1] if xy[1] != " " else xy[0])
        d[p] = {"C": "A", "T": "M"}.get(st, st)
    return d


def numstat(root, dirty):
    """path -> (added, deleted); untracked files count as all added."""
    out = run("git", "-C", root, "diff", "--numstat", "-z", "HEAD")
    if out is None:  # no commit yet
        out = run("git", "-C", root, "diff", "--numstat", "-z") or ""
    toks, i, s = out.split("\0"), 0, {}
    while i < len(toks):
        t = toks[i]
        if t.count("\t") < 2:
            i += 1
            continue
        a, dl, p = t.split("\t", 2)
        if p == "":  # rename: old and new name follow
            p = toks[i + 2] if i + 2 < len(toks) else ""
            i += 3
        else:
            i += 1
        s[p] = (a, dl)
    for p, st in dirty.items():
        if st == "?":
            try:
                f = os.path.join(root, p)
                # shortcut: line count skipped above 1 MB, shows no +N then
                if os.path.getsize(f) < 1 << 20:
                    with open(f, "rb") as fh:
                        s[p] = (str(fh.read().count(b"\n")), "0")
            except OSError:
                pass
    return s


def ancestors(p):
    parts = p.split("/")
    return ["/".join(parts[:i]) for i in range(1, len(parts))]


def age(sec):
    for unit, n in (("d", 86400), ("h", 3600), ("m", 60)):
        if sec >= n:
            return f"{int(sec // n)}{unit}"
    return f"{int(sec)}s"


class Tree:
    def __init__(self):
        self.root: str = ""
        self.dirty: dict[str, str] = {}
        self.mtime: dict[str, float] = {}
        self.reset()

    def reset(self):
        self.dirty, self.stats, self.mtime = {}, {}, {}
        self.kids = {"": [set(), set()]}
        self.count = {}
        self.manual_open, self.manual_closed = set(), set()
        self.sig = None
        self.listed_at = 0

    def refresh(self, root: str):
        if root != self.root:
            self.root = root
            self.reset()
        if not root:
            return
        dirty = status(root)
        sig = tuple(sorted(dirty.items()))
        # Change list or 10s passed: re-read listing and line counts.
        if sig != self.sig or time.time() - self.listed_at > 10:
            for p in set(dirty) - set(self.dirty):  # new change: reveal its path again
                self.manual_closed.difference_update(ancestors(p))
            self.dirty, self.sig, self.listed_at = dirty, sig, time.time()
            self.stats = numstat(root, dirty)
            ls = run("git", "-C", root, "ls-files", "-z", "--cached", "--others", "--exclude-standard") or ""
            self.build(set(filter(None, ls.split("\0"))) | set(dirty))
        self.mtime = {}
        for p in self.dirty:
            try:
                self.mtime[p] = os.lstat(os.path.join(self.root, p)).st_mtime
            except OSError:  # deleted file: no age
                continue

    def build(self, paths):
        kids = {"": [set(), set()]}
        for p in paths:
            anc = [""] + ancestors(p)
            for parent, child in zip(anc, anc[1:], strict=False):
                kids.setdefault(parent, [set(), set()])[0].add(child)
                kids.setdefault(child, [set(), set()])
            kids.setdefault(anc[-1], [set(), set()])[1].add(p)
        self.kids = kids
        self.count = {}
        for p in self.dirty:
            for a in [""] + ancestors(p):
                self.count[a] = self.count.get(a, 0) + 1

    def auto(self, d):
        return self.count.get(d, 0) > 0

    def is_open(self, d):
        return d == "" or (d not in self.manual_closed and (d in self.manual_open or self.auto(d)))

    def toggle(self, d, want):
        if want:
            self.manual_closed.discard(d)
            if not self.auto(d):
                self.manual_open.add(d)
        else:
            self.manual_open.discard(d)
            if self.auto(d):
                self.manual_closed.add(d)

    def collapse_all(self):
        self.manual_open.clear()
        self.manual_closed = {d for d in self.kids if d and self.auto(d)}

    def default_view(self):
        """Drop every manual open/close: back to just the paths to changed files."""
        self.manual_open.clear()
        self.manual_closed.clear()

    def rows(self, changed_only) -> list[tuple[str, str, int]]:
        """[(kind, path, depth)] in display order."""
        out: list[tuple[str, str, int]] = []

        def walk(d, depth):
            subs, files = self.kids.get(d, (set(), set()))
            for s in sorted(subs, key=lambda x: x.rsplit("/", 1)[-1].lower()):
                if changed_only and not self.count.get(s):
                    continue
                out.append(("d", s, depth))
                if self.is_open(s):
                    walk(s, depth + 1)
            for f in sorted(files, key=lambda x: x.rsplit("/", 1)[-1].lower()):
                if changed_only and f not in self.dirty:
                    continue
                out.append(("f", f, depth))

        walk("", 0)
        return out


def line(t, kind, p, depth, w, newest, selected):
    name = p.rsplit("/", 1)[-1]
    ind = "  " * depth
    if kind == "d":
        n = t.count.get(p, 0)
        opened = t.is_open(p)
        left = f" {ind}{'▾' if opened else '▸'} "
        ic, iw = icon(name, True, opened)
        badge = f" ● {n}" if n and not opened else ""
        room = max(1, w - len(left) - iw - len(badge) - 1)
        nm = (name + "/")[:room]
        body = f"{fg('dim')}{left}{ic}{fg('dir' if n else 'text')}{nm}{fg('M')}{badge}"
        vis = len(left) + iw + len(nm) + len(badge)
    else:
        st = t.dirty.get(p)
        left = f" {ind}"
        mark = st or " "
        right = ""
        if st:
            a, dl = t.stats.get(p, ("", ""))
            if a not in ("", "-"):
                right += f"{fg('add')}+{a}"
            if dl not in ("", "-", "0"):
                right += f" {fg('del')}-{dl}"
            if p in t.mtime:
                right += f" {fg('dim')}{age(max(0, time.time() - t.mtime[p]))}"
        rvis = len(re.sub(r"\x1b\[[0-9;]*m", "", right))
        ic, iw = icon(name)
        room = max(1, w - len(left) - 2 - iw - rvis - 2)
        nm = name if len(name) <= room else name[: room - 1] + "…"
        bold = "\x1b[1m" if p == newest else ""
        body = (f"{left}{fg(st) if st else ''}{mark}{OFF}{SEL_BG if selected else ''} {ic}"
                f"{bold}{fg(st) if st else fg('text')}{nm}{OFF}{SEL_BG if selected else ''}")
        vis = len(left) + 2 + iw + len(nm)
        pad = max(1, w - vis - rvis - 1)
        body += " " * pad + right
        vis += pad + rvis
    bg = SEL_BG if selected else ""
    return f"{bg}{body}{bg}{' ' * max(0, w - vis)}{OFF}"


def popup(root, cmd):
    sp.Popen(["tmux", "display-popup", "-E", "-w", "90%", "-h", "90%", "-d", root, cmd],
             stdout=sp.DEVNULL, stderr=sp.DEVNULL)


def main():
    tmux("set", "-p", "-t", PANE, "@filetree", "1", ";", "select-pane", "-t", PANE, "-T", "files")
    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd)
    tty.setcbreak(fd)
    sys.stdout.write("\x1b[?25l\x1b[?7l")
    t = Tree()
    sel, top, changed_only, msg, msg_at = None, 0, False, "", 0
    agent_pane = agent_cwd = None
    last = 0
    try:
        while True:
            if time.time() - last >= 1:
                root, agent_pane, agent_cwd, n = window()
                if n <= 1:  # last pane left in the window: close
                    return
                t.refresh(root or "")
                last = time.time()
            cols, lines = os.get_terminal_size()
            rows = t.rows(changed_only) if t.root else []
            keys = [k + p for k, p, _ in rows]
            idx = keys.index(sel) if sel in keys else 0
            body_h = max(1, lines - 3)
            top = min(top, idx)
            if idx >= top + body_h:
                top = idx - body_h + 1
            newest = max(t.mtime, key=lambda p: t.mtime[p]) if t.mtime else None
            out = ["\x1b[H"]
            if t.root:
                branch = (run("git", "-C", t.root, "branch", "--show-current") or "").strip()
                head = f" \x1b[1m{fg('text')}{os.path.basename(t.root)}{OFF} {fg('dim')}{branch}"
                head += f"  {fg('M')}{len(t.dirty)} changed" if t.dirty else ""
            else:
                head = f" {fg('dim')}not a git repo"
            out.append(head + OFF + "\x1b[K\r\n\x1b[K\r\n")
            for i in range(body_h):
                j = top + i
                if j < len(rows):
                    kind, path, depth = rows[j]
                    out.append(line(t, kind, path, depth, cols, newest, j == idx))
                out.append("\x1b[K\r\n")
            hint = msg if msg and time.time() - msg_at < 3 else "⏎ open d diff r ref a " + ("all" if changed_only else "changed") + " q"
            out.append(f"{fg('dim')} {hint[: cols - 2]}{OFF}\x1b[K")
            sys.stdout.write("".join(out))
            sys.stdout.flush()

            r, _, _ = select.select([fd], [], [], max(0.05, 1 - (time.time() - last)))
            if not r:
                continue
            # One read can hold several keys (repeat, fast typing): handle each.
            for k in re.findall(r"\x1b\[[A-D]|.", os.read(fd, 64).decode(errors="ignore"), re.S):
                idx, changed_only, msg, msg_at = key(t, k, rows, keys, idx, changed_only, agent_pane, agent_cwd, msg, msg_at)
                if idx < 0:
                    return
                sel = keys[idx] if keys else None
                rows = t.rows(changed_only) if t.root else []
                keys = [kk + p for kk, p, _ in rows]
                idx = keys.index(sel) if sel in keys else min(idx, max(0, len(rows) - 1))
            sel = keys[idx] if keys else None
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, saved)
        sys.stdout.write("\x1b[?25h\x1b[?7h" + OFF)
        sys.stdout.flush()


def key(t, k, rows, keys, idx, changed_only, agent_pane, agent_cwd, msg, msg_at):
    """Handle one key; returns new (idx, changed_only, msg, msg_at), idx -1 = quit."""
    cur = rows[idx] if rows else None
    if k == "q":
        tmux("set", "-w", "-t", PANE, "@filetree_off", "1")
        return -1, changed_only, msg, msg_at
    elif k in ("j", "\x1b[B"):
        idx = min(idx + 1, len(rows) - 1)
    elif k in ("k", "\x1b[A"):
        idx = max(idx - 1, 0)
    elif k == "g":
        idx = 0
    elif k == "G":
        idx = len(rows) - 1
    elif k == "a":
        changed_only = not changed_only
    elif k == "c":
        t.collapse_all()
    elif k == "e":
        t.default_view()
    elif cur and k in ("l", "\x1b[C", "\r", "\n") and cur[0] == "d":
        t.toggle(cur[1], not t.is_open(cur[1]) if k in ("\r", "\n") else True)
    elif cur and k in ("h", "\x1b[D"):
        if cur[0] == "d" and t.is_open(cur[1]):
            t.toggle(cur[1], False)
        elif "/" in cur[1]:  # jump to the parent folder
            parent = "d" + cur[1].rsplit("/", 1)[0]
            idx = keys.index(parent) if parent in keys else idx
    elif cur and k in ("\r", "\n"):
        popup(t.root, "nvim -- " + shlex.quote(cur[1]))
    elif cur and k == "d":
        q = shlex.quote(cur[1])
        popup(t.root, f"{{ git diff --color=always HEAD -- {q} 2>/dev/null;"
                      f" git ls-files --error-unmatch -- {q} >/dev/null 2>&1 ||"
                      f" git diff --color=always --no-index /dev/null {q}; }} | less -R")
    elif cur and k == "r":
        if agent_pane:
            full = os.path.join(t.root, cur[1])
            rel = os.path.relpath(full, agent_cwd) if agent_cwd and full.startswith(agent_cwd.rstrip("/") + "/") else full
            tmux("set-buffer", "-b", "filetree", "--", f"@{rel} ", ";",
                 "paste-buffer", "-p", "-d", "-b", "filetree", "-t", agent_pane)
            msg = f"sent @{rel}"
        else:
            msg = "no agent in this window"
        msg_at = time.time()
    return max(0, min(idx, len(rows) - 1)), changed_only, msg, msg_at


if __name__ == "__main__":
    main()
