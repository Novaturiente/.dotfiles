#!/usr/bin/env node
// Git-aware file tree, the "Files" tab of the pi side panel (see index.ts).
//
// Root = git top folder of the owning pi pane's folder (@agent_cwd, else its current path),
// so a worktree shows the worktree. Folders open only along the paths to changed files
// (git status); one you open or close by hand stays that way until a new change appears
// inside it. Committed = folds away again.
// Keys: j/k move, l/h open/close, enter open (file: nvim popup), d diff popup, r paste @path
// into pi, a changed-only view, g/G top/bottom, c collapse all, e default view (only the
// paths to changes open), Tab next panel tab, q close (stays closed until /files).
import { execFileSync, spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { closeAll, closeTab, cycle, ownerGone, tabBar } from "../panel/lib.mjs";

const PANE = process.env.TMUX_PANE ?? "";
// Set by the panel's openTab(): the pi pane this tree belongs to, and the panel's state dir.
const OWNER = process.env.PI_PANEL_OWNER ?? "";
const PDIR = process.env.PI_PANEL_DIR ?? "";

// Catppuccin Mocha
const C = {
	M: "249;226;175", A: "166;227;161", "?": "166;227;161", D: "243;139;168", R: "137;180;250", U: "243;139;168",
	dir: "137;180;250", text: "205;214;244", dim: "108;112;134", add: "166;227;161", del: "243;139;168",
};
const SEL_BG = "\x1b[48;2;49;50;68m";
const OFF = "\x1b[0m";
const fg = (name) => `\x1b[38;2;${C[name]}m`;

// Icons (Nerd Font glyphs, all checked in ZedMono Nerd Font). ICONS = false hides them.
// Add a type: extension (lower case) or exact file name -> [glyph, colour].
const ICONS = true;
const [Y, B, S, G, P, R, X, GREY] = ["249;226;175", "137;180;250", "137;220;235", "166;227;161", "250;179;135", "243;139;168", "205;214;244", "147;153;178"];
const FOLDER = ["\ue5ff", "\ue5fe"]; // closed, open
const FILE = ["\uf15b", GREY]; // no match
const CONFIG = ["\ue615", GREY], IMAGE = ["\ue60d", P], SHELL = ["\ue691", G];
const EXT = {
	py: ["\ue606", Y], js: ["\ue60c", Y], mjs: ["\ue60c", Y], cjs: ["\ue60c", Y],
	ts: ["\ue628", B], tsx: ["\ue625", S], jsx: ["\ue625", S], json: ["\u{f0626}", Y],
	md: ["\ue609", X], txt: ["\ue64e", X], sh: SHELL, bash: SHELL, zsh: SHELL,
	fish: SHELL, lua: ["\ue620", B], rs: ["\ue68b", P], go: ["\ue627", S],
	html: ["\ue60e", P], css: ["\ue614", B], scss: ["\ue603", R], sass: ["\ue603", R],
	yml: ["\ue6a8", R], yaml: ["\ue6a8", R], toml: CONFIG, ini: CONFIG, conf: CONFIG,
	kdl: CONFIG, xml: ["\ue619", P], c: ["\ue649", B], h: ["\ue649", B],
	cpp: ["\ue646", B], java: ["\ue66d", R], kt: ["\ue634", P], rb: ["\ue605", R],
	php: ["\ue608", B], swift: ["\ue699", P], vue: ["\ue6a0", G], svelte: ["\ue697", P],
	nix: ["\u{f1105}", B], vim: ["\ue62b", G], sql: ["\ue64d", X], db: ["\ue64d", X],
	csv: ["\ue64a", G], pdf: ["\ue67d", R], zip: ["\ue6aa", Y], gz: ["\ue6aa", Y],
	tar: ["\ue6aa", Y], svg: ["\ue698", Y], png: IMAGE, jpg: IMAGE, jpeg: IMAGE,
	gif: IMAGE, webp: IMAGE, ico: IMAGE, mp4: ["\ue69f", P], mp3: ["\ue638", S],
	lock: ["\ue672", GREY],
};
const NAMES = {
	Makefile: ["\ue673", P], Dockerfile: ["\ue650", B], LICENSE: ["\ue60a", Y],
	".gitignore": ["\ue702", P], ".gitattributes": ["\ue702", P], ".gitmodules": ["\ue702", P],
	"package-lock.json": ["\ue672", GREY], "tsconfig.json": ["\ue69d", B],
};

/** [coloured glyph + space, cells]; every glyph is 1 cell (Nerd Font Mono). */
function icon(name, folder = false, opened = false) {
	if (!ICONS) return ["", 0];
	const ext = name.includes(".") ? name.split(".").pop().toLowerCase() : "";
	const [g, c] = folder ? [FOLDER[opened ? 1 : 0], B] : NAMES[name] ?? EXT[ext] ?? FILE;
	return [`\x1b[38;2;${c}m${g} `, 2];
}

// Widths count code points: astral glyphs are 2 UTF-16 units but 1 cell.
const len = (s) => [...s].length;
const cut = (s, n) => [...s].slice(0, Math.max(0, n)).join("");

/** stdout of a command, or null when it fails. */
function run(cmd, ...args) {
	try {
		return execFileSync(cmd, args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], maxBuffer: 64 << 20 });
	} catch {
		return null;
	}
}
const tmux = (...a) => run("tmux", ...a) ?? "";

const topCache = new Map();
function toplevel(d) {
	if (!topCache.has(d)) topCache.set(d, (run("git", "-C", d, "rev-parse", "--show-toplevel") ?? "").trim() || null);
	return topCache.get(d);
}

/** { root, cwd } from the owning pi pane, or null once that pane is gone. */
function owner() {
	const row = tmux("display", "-p", "-t", OWNER, "#{pane_id}\t#{@agent_cwd}\t#{pane_current_path}").trim().split("\t");
	if (!OWNER || row.length !== 3 || row[0] !== OWNER) return null;
	const cwd = row[1] || row[2];
	return { root: toplevel(cwd), cwd };
}

/** path -> one status letter, from git status -z (renames: new path). */
function status(root) {
	const parts = (run("git", "-C", root, "status", "--porcelain=v1", "-z", "-uall") ?? "").split("\0");
	const d = new Map();
	for (let i = 0; i < parts.length; ) {
		const e = parts[i++];
		if (e.length < 4) continue;
		const xy = e.slice(0, 2), p = e.slice(3);
		if ("RC".includes(xy[0])) i++; // -z puts the old name in the next field
		const st = xy === "??" ? "?" : xy[1] !== " " ? xy[1] : xy[0];
		d.set(p, { C: "A", T: "M" }[st] ?? st);
	}
	return d;
}

/** path -> [added, deleted]; untracked files count as all added. */
function numstat(root, dirty) {
	const out = run("git", "-C", root, "diff", "--numstat", "-z", "HEAD") ?? run("git", "-C", root, "diff", "--numstat", "-z") ?? ""; // no commit yet
	const toks = out.split("\0"), s = new Map();
	for (let i = 0; i < toks.length; ) {
		const t = toks[i];
		if (t.split("\t").length < 3) {
			i++;
			continue;
		}
		const [a, dl, ...rest] = t.split("\t");
		let p = rest.join("\t");
		if (p === "") {
			// rename: old and new name follow
			p = toks[i + 2] ?? "";
			i += 3;
		} else i++;
		s.set(p, [a, dl]);
	}
	for (const [p, st] of dirty) {
		if (st !== "?") continue;
		try {
			const f = path.join(root, p);
			// shortcut: line count skipped above 1 MB, shows no +N then
			if (fs.statSync(f).size < 1 << 20) s.set(p, [String(fs.readFileSync(f).filter((b) => b === 10).length), "0"]);
		} catch {
			// vanished or unreadable: no counts
		}
	}
	return s;
}

const ancestors = (p) => {
	const parts = p.split("/");
	return parts.slice(1).map((_, i) => parts.slice(0, i + 1).join("/"));
};
const base = (p) => p.slice(p.lastIndexOf("/") + 1);
const byName = (a, b) => {
	const x = base(a).toLowerCase(), y = base(b).toLowerCase();
	return x < y ? -1 : x > y ? 1 : 0;
};

function age(sec) {
	for (const [unit, n] of [["d", 86400], ["h", 3600], ["m", 60]]) if (sec >= n) return `${Math.floor(sec / n)}${unit}`;
	return `${Math.floor(sec)}s`;
}

class Tree {
	root = "";
	constructor() {
		this.reset();
	}

	reset() {
		this.dirty = new Map();
		this.stats = new Map();
		this.mtime = new Map();
		this.kids = new Map([["", [new Set(), new Set()]]]);
		this.count = new Map();
		this.manualOpen = new Set();
		this.manualClosed = new Set();
		this.sig = null;
		this.listedAt = 0;
		this.branch = "";
	}

	refresh(root) {
		if (root !== this.root) {
			this.root = root;
			this.reset();
		}
		if (!root) return;
		const dirty = status(root);
		const sig = JSON.stringify([...dirty].sort());
		// Change list or 10 s passed: re-read listing and line counts.
		if (sig !== this.sig || Date.now() - this.listedAt > 10_000) {
			for (const p of dirty.keys()) if (!this.dirty.has(p)) for (const a of ancestors(p)) this.manualClosed.delete(a); // new change: reveal its path again
			this.dirty = dirty;
			this.sig = sig;
			this.listedAt = Date.now();
			this.stats = numstat(root, dirty);
			const ls = run("git", "-C", root, "ls-files", "-z", "--cached", "--others", "--exclude-standard") ?? "";
			this.build(new Set([...ls.split("\0").filter(Boolean), ...dirty.keys()]));
		}
		this.branch = (run("git", "-C", root, "branch", "--show-current") ?? "").trim();
		this.mtime = new Map();
		for (const p of this.dirty.keys()) {
			try {
				this.mtime.set(p, fs.lstatSync(path.join(root, p)).mtimeMs / 1000);
			} catch {
				// deleted file: no age
			}
		}
	}

	build(paths) {
		const kids = new Map([["", [new Set(), new Set()]]]);
		const node = (d) => kids.get(d) ?? kids.set(d, [new Set(), new Set()]).get(d);
		for (const p of paths) {
			const anc = ["", ...ancestors(p)];
			for (let i = 1; i < anc.length; i++) {
				node(anc[i - 1])[0].add(anc[i]);
				node(anc[i]);
			}
			node(anc.at(-1))[1].add(p);
		}
		this.kids = kids;
		this.count = new Map();
		for (const p of this.dirty.keys()) for (const a of ["", ...ancestors(p)]) this.count.set(a, (this.count.get(a) ?? 0) + 1);
	}

	auto(d) {
		return (this.count.get(d) ?? 0) > 0;
	}

	isOpen(d) {
		return d === "" || (!this.manualClosed.has(d) && (this.manualOpen.has(d) || this.auto(d)));
	}

	toggle(d, want) {
		if (want) {
			this.manualClosed.delete(d);
			if (!this.auto(d)) this.manualOpen.add(d);
		} else {
			this.manualOpen.delete(d);
			if (this.auto(d)) this.manualClosed.add(d);
		}
	}

	collapseAll() {
		this.manualOpen.clear();
		this.manualClosed = new Set([...this.kids.keys()].filter((d) => d && this.auto(d)));
	}

	/** Drop every manual open/close: back to just the paths to changed files. */
	defaultView() {
		this.manualOpen.clear();
		this.manualClosed.clear();
	}

	/** [{kind: "d"|"f", path, depth}] in display order. */
	rows(changedOnly) {
		const out = [];
		const walk = (d, depth) => {
			const [subs, files] = this.kids.get(d) ?? [new Set(), new Set()];
			for (const s of [...subs].sort(byName)) {
				if (changedOnly && !this.count.get(s)) continue;
				out.push({ kind: "d", path: s, depth });
				if (this.isOpen(s)) walk(s, depth + 1);
			}
			for (const f of [...files].sort(byName)) {
				if (changedOnly && !this.dirty.has(f)) continue;
				out.push({ kind: "f", path: f, depth });
			}
		};
		walk("", 0);
		return out;
	}
}

function line(t, { kind, path: p, depth }, w, newest, selected) {
	const name = base(p);
	const ind = "  ".repeat(depth);
	const sbg = selected ? SEL_BG : "";
	let body, vis;
	if (kind === "d") {
		const n = t.count.get(p) ?? 0;
		const opened = t.isOpen(p);
		const left = ` ${ind}${opened ? "▾" : "▸"} `;
		const [ic, iw] = icon(name, true, opened);
		const badge = n && !opened ? ` ● ${n}` : "";
		const room = Math.max(1, w - len(left) - iw - len(badge) - 1);
		const nm = cut(`${name}/`, room);
		body = `${fg("dim")}${left}${ic}${fg(n ? "dir" : "text")}${nm}${fg("M")}${badge}`;
		vis = len(left) + iw + len(nm) + len(badge);
	} else {
		const st = t.dirty.get(p);
		const left = ` ${ind}`;
		let right = "";
		if (st) {
			const [a = "", dl = ""] = t.stats.get(p) ?? [];
			if (a !== "" && a !== "-") right += `${fg("add")}+${a}`;
			if (!["", "-", "0"].includes(dl)) right += ` ${fg("del")}-${dl}`;
			if (t.mtime.has(p)) right += ` ${fg("dim")}${age(Math.max(0, Date.now() / 1000 - t.mtime.get(p)))}`;
		}
		const rvis = len(right.replace(/\x1b\[[0-9;]*m/g, ""));
		const [ic, iw] = icon(name);
		const room = Math.max(1, w - len(left) - 2 - iw - rvis - 2);
		const nm = len(name) <= room ? name : `${cut(name, room - 1)}…`;
		const bold = p === newest ? "\x1b[1m" : "";
		const col = st ? fg(st) : "";
		body = `${left}${col}${st ?? " "}${OFF}${sbg} ${ic}${bold}${st ? fg(st) : fg("text")}${nm}${OFF}${sbg}`;
		vis = len(left) + 2 + iw + len(nm);
		const pad = Math.max(1, w - vis - rvis - 1);
		body += " ".repeat(pad) + right;
		vis += pad + rvis;
	}
	return `${sbg}${body}${sbg}${" ".repeat(Math.max(0, w - vis))}${OFF}`;
}

function popup(root, cmd) {
	spawn("tmux", ["display-popup", "-E", "-w", "90%", "-h", "90%", "-d", root, cmd], { detached: true, stdio: "ignore" }).unref();
}

const q = (s) => `'${s.replace(/'/g, `'\\''`)}'`; // POSIX shell quote

// ---------- state and screen ----------

const t = new Tree();
let sel = null; // "d<path>" / "f<path>" of the selected row
let top = 0;
let changedOnly = false;
let msg = "";
let msgAt = 0;
let agent = null; // { root, cwd } of the owning pi pane

const keyOf = (r) => r.kind + r.path;
const current = () => {
	const rows = t.root ? t.rows(changedOnly) : [];
	const keys = rows.map(keyOf);
	return { rows, keys, idx: Math.max(0, keys.indexOf(sel)) };
};

function render() {
	const cols = process.stdout.columns || 40;
	const lines = process.stdout.rows || 24;
	const { rows, idx } = current();
	const bodyH = Math.max(1, lines - 3);
	top = Math.min(top, idx);
	if (idx >= top + bodyH) top = idx - bodyH + 1;
	let newest = null;
	for (const [p, m] of t.mtime) if (newest === null || m > t.mtime.get(newest)) newest = p;
	const head = t.root
		? ` \x1b[1m${fg("text")}${path.basename(t.root)}${OFF} ${fg("dim")}${t.branch}${t.dirty.size ? `  ${fg("M")}${t.dirty.size} changed` : ""}`
		: ` ${fg("dim")}not a git repo`;
	const tabs = tabBar(PANE);
	const bar = tabs.length > 1 ? tabs.map((x) => (x.active ? `\x1b[1;7m ${x.title} ${OFF}` : `${fg("dim")} ${x.title} ${OFF}`)).join("") : "";
	// Tab bar on top like the panel viewer; without other tabs, a blank line under the head.
	const out = ["\x1b[H", bar ? `${bar}${OFF}\x1b[K\r\n${head}${OFF}\x1b[K\r\n` : `${head}${OFF}\x1b[K\r\n\x1b[K\r\n`];
	for (let i = 0; i < bodyH; i++) {
		const j = top + i;
		if (j < rows.length) out.push(line(t, rows[j], cols, newest, j === idx));
		out.push("\x1b[K\r\n");
	}
	const hint = msg && Date.now() - msgAt < 3000 ? msg : `⏎ open d diff r ref a ${changedOnly ? "all" : "changed"} ⇥ tab q`;
	out.push(`${fg("dim")} ${cut(hint, cols - 2)}${OFF}\x1b[K`);
	process.stdout.write(out.join(""));
}

function refresh() {
	agent = owner();
	if (!agent || ownerGone()) {
		closeAll(); // owning pi exited (quit, crash, pane closed): take every tab down
		return quit();
	}
	t.refresh(agent.root ?? "");
	render();
}

function key(k) {
	const { rows, keys } = current();
	let { idx } = current();
	const cur = rows[idx];
	if (k === "q" || k === "\x03") {
		closeTab("files"); // kills this pane; the next tab takes the slot
		return quit();
	}
	if (k === "\t") cycle();
	else if (k === "j" || k === "\x1b[B") idx = Math.min(idx + 1, rows.length - 1);
	else if (k === "k" || k === "\x1b[A") idx = Math.max(idx - 1, 0);
	else if (k === "g") idx = 0;
	else if (k === "G") idx = rows.length - 1;
	else if (k === "a") changedOnly = !changedOnly;
	else if (k === "c") t.collapseAll();
	else if (k === "e") t.defaultView();
	else if (cur && ["l", "\x1b[C", "\r", "\n"].includes(k) && cur.kind === "d") t.toggle(cur.path, k === "\r" || k === "\n" ? !t.isOpen(cur.path) : true);
	else if (cur && (k === "h" || k === "\x1b[D")) {
		if (cur.kind === "d" && t.isOpen(cur.path)) t.toggle(cur.path, false);
		else if (cur.path.includes("/")) {
			// jump to the parent folder
			const parent = `d${cur.path.slice(0, cur.path.lastIndexOf("/"))}`;
			if (keys.includes(parent)) idx = keys.indexOf(parent);
		}
	} else if (cur && (k === "\r" || k === "\n")) popup(t.root, `nvim -- ${q(cur.path)}`);
	else if (cur && k === "d") {
		const f = q(cur.path);
		popup(t.root, `{ git diff --color=always HEAD -- ${f} 2>/dev/null; git ls-files --error-unmatch -- ${f} >/dev/null 2>&1 || git diff --color=always --no-index /dev/null ${f}; } | less -R`);
	} else if (cur && k === "r") {
		const full = path.join(t.root, cur.path);
		const cwd = agent?.cwd;
		const rel = cwd && full.startsWith(`${cwd.replace(/\/$/, "")}/`) ? path.relative(cwd, full) : full;
		tmux("set-buffer", "-b", "filetree", "--", `@${rel} `, ";", "paste-buffer", "-p", "-d", "-b", "filetree", "-t", OWNER);
		msg = `sent @${rel}`;
		msgAt = Date.now();
	}
	// Keep the selection on the same row when rows move (folds, view switch).
	const prev = keys[Math.max(0, Math.min(idx, keys.length - 1))] ?? null;
	const after = current().keys;
	sel = after.includes(prev) ? prev : (after[Math.min(idx, after.length - 1)] ?? null);
}

function quit() {
	process.stdout.write(`\x1b[?25h\x1b[?7h${OFF}`);
	process.exit(0);
}

tmux("select-pane", "-t", PANE, "-T", "files");
process.stdout.write("\x1b[2J\x1b[?25l\x1b[?7l");
process.stdin.setRawMode?.(true);
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
	// One read can hold several keys (repeat, fast typing): handle each.
	for (const k of chunk.match(/\x1b\[[A-D]|[\s\S]/g) ?? []) key(k);
	render();
});
process.stdout.on("resize", render);
setInterval(refresh, 1000);
refresh();
