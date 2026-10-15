#!/usr/bin/env node
// Panel viewer: renders every source under <panelDir>/sources as one tree.
// Keys: j/k or arrows move, g/G top/bottom, Enter runs the node's "enter" action,
// other keys run the node action with that key, Tab shows the next tab, q closes this tab.
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { closeAll, closeTab, cycle, ownerGone, tabBar } from "./lib.mjs";

const dir = process.argv[2];
if (!dir) {
	console.error("usage: viewer.mjs <panelDir>");
	process.exit(1);
}
const sourcesDir = path.join(dir, "sources");
// Actions run in this pane, whose TMUX_PANE is the viewer's: point them at the real panel and owner.
const panelEnv = { PI_PANEL_DIR: dir, PI_PANEL_OWNER: (() => { try { return fs.readFileSync(path.join(dir, "owner"), "utf8").trim(); } catch { return ""; } })() };
const out = process.stdout;

// Nerd Font status glyphs (a node's own `icon: [glyph, color]` wins).
const ICON = {
	running: ["\uf04b", 33], starting: ["\uf110", 33], waiting: ["\uf128", 35], queued: ["\uf017", 90],
	done: ["\uf00c", 32], idle: ["\uf10c", 36], failed: ["\uf00d", 31], stopped: ["\uf04d", 90],
};
const color = (code, s) => `\x1b[${code}m${s}\x1b[0m`;
const strip = (s) => s.replace(/\x1b\[[0-9;]*m/g, "");
const width = (s) => [...strip(s)].length; // code points: Nerd Font glyphs above U+FFFF are one cell

let rows = []; // flattened: { kind: "header", title } | { kind: "node", node, depth }
let selected = 0;
let message = "";

function readJson(f) {
	try {
		return JSON.parse(fs.readFileSync(f, "utf8"));
	} catch {
		return undefined;
	}
}

function load() {
	const next = [];
	if (!fs.existsSync(sourcesDir)) return next;
	const sources = fs.readdirSync(sourcesDir).map((name) => {
		const d = path.join(sourcesDir, name);
		const meta = readJson(path.join(d, "_source.json")) ?? { title: name, order: 50 };
		const nodes = fs.readdirSync(d).filter((f) => f.endsWith(".json") && f !== "_source.json").map((f) => readJson(path.join(d, f))).filter(Boolean);
		return { name, meta, nodes };
	}).filter((s) => s.nodes.length).sort((a, b) => (a.meta.order ?? 50) - (b.meta.order ?? 50) || a.name.localeCompare(b.name));
	const cmp = (a, b) => (a.order ?? 0) - (b.order ?? 0) || String(a.id).localeCompare(String(b.id), undefined, { numeric: true });
	for (const s of sources) {
		if (next.length) next.push({ kind: "rule" });
		const headed = s.meta.title !== ""; // title "" = no header; the roots head the section themselves
		if (headed) next.push({ kind: "header", title: s.meta.title ?? s.name });
		const ids = new Set(s.nodes.map((n) => n.id));
		const kidsOf = (parent) => {
			const kids = s.nodes.filter((n) => (n.parent && ids.has(n.parent) ? n.parent : undefined) === parent).sort(cmp);
			return s.meta.newestFirst ? kids.reverse() : kids;
		};
		// prefix: tree guides of the ancestors; every node hangs off its parent (roots off the header).
		const walk = (parent, prefix) => {
			const kids = kidsOf(parent);
			kids.forEach((n, i) => {
				const last = i === kids.length - 1;
				const root = !headed && parent === undefined;
				const below = root ? prefix : prefix + (last ? "  " : "│ ");
				const guide = root ? prefix : prefix + (last ? "└─" : "├─");
				next.push({ kind: "node", node: n, source: s.name, guide, below, hasKids: kidsOf(n.id).length > 0 });
				walk(n.id, below);
			});
		};
		walk(undefined, " ");
	}
	return next;
}

function elapsed(ms) {
	const s = Math.max(0, Math.floor(ms / 1000));
	if (s < 60) return `${s}s`;
	if (s < 3600) return `${Math.floor(s / 60)}m${String(s % 60).padStart(2, "0")}s`;
	return `${Math.floor(s / 3600)}h${String(Math.floor((s % 3600) / 60)).padStart(2, "0")}m`;
}

/** Cut to w cells, keeping colours. */
function fit(s, w) {
	if (width(s) <= w) return s;
	let out = "";
	let n = 0;
	for (const part of s.split(/(\x1b\[[0-9;]*m)/)) {
		if (part.startsWith("\x1b[")) out += part;
		else
			for (const ch of part) {
				if (n >= w - 1) return `${out}…\x1b[0m`;
				out += ch;
				n++;
			}
	}
	return out;
}
/** left … right on one line of w cells; right wins the space. */
function spread(left, right, w) {
	if (!right) return fit(left, w);
	const l = fit(left, Math.max(1, w - width(right) - 1));
	return l + " ".repeat(Math.max(1, w - width(l) - width(right))) + right;
}
const timeOf = (t) => (t && (t.ms || t.since) ? elapsed((t.ms ?? 0) + (t.since ? Date.now() - t.since : 0)) : "");

function render() {
	const prevId = rows[selected]?.node?.id;
	rows = load();
	const nodeRows = rows.map((r, i) => (r.kind === "node" ? i : -1)).filter((i) => i >= 0);
	const keep = rows.findIndex((r) => r.node?.id === prevId);
	selected = keep >= 0 ? keep : nodeRows[0] ?? 0;
	if (rows[selected]?.kind !== "node") selected = nodeRows.find((i) => i >= selected) ?? nodeRows.at(-1) ?? 0;

	const w = out.columns || 40;
	const h = out.rows || 24;
	const lines = [];
	const bar = tabBar(process.env.TMUX_PANE);
	if (bar.length > 1) lines.push(fit(bar.map((t) => (t.active ? `\x1b[1;7m ${t.title} \x1b[0m` : color(90, ` ${t.title} `))).join(""), w), "");
	let selLine = 0;
	rows.forEach((r, i) => {
		if (r.kind === "rule") {
			lines.push("", color(90, "─".repeat(w)));
			return;
		}
		if (r.kind === "header") {
			lines.push(fit(`\x1b[1;34m ${r.title}\x1b[0m`, w));
			return;
		}
		const n = r.node;
		const [icon, code] = n.icon ?? ICON[n.status] ?? ["•", 37];
		const label = n.dim ? color("2;9", n.label ?? n.id) : `\x1b[1m${n.label ?? n.id}\x1b[0m`;
		const left = `${color(90, r.guide)}${color(code, icon)} ${label}${n.tag ? color(90, ` ${n.tag}`) : ""}`;
		const time = timeOf(n.time);
		const head = spread(left, time ? color(n.time.since ? 33 : 90, time) : "", w);
		if (i === selected) selLine = lines.length;
		lines.push(i === selected && focused ? `\x1b[7m${strip(head)}${" ".repeat(Math.max(0, w - width(head)))}\x1b[0m` : head);
		// Details hang under the label; the guide keeps the tree line going to the children.
		const pad = color(90, r.below + (r.hasKids ? "│ " : "  "));
		for (const d of [n.detail ?? []].flat()) if (d) lines.push(fit(`${pad}\x1b[90m${d.replaceAll("\x1b[0m", "\x1b[0;90m")}\x1b[0m`, w));
	});
	if (!rows.length) lines.push(color(90, " (empty)"));

	const sel = focused ? rows[selected]?.node : undefined;
	const acts = Object.entries(sel?.actions ?? {}).map(([k, a]) => `${k === "enter" ? "⏎" : k} ${a.label ?? ""}`);
	const footer = [message ? color(33, fit(message, w)) : "", color(90, fit([...acts, ...(bar.length > 1 ? ["⇥ tab"] : []), "q close"].join("  "), w))].filter(Boolean);
	const body = h - footer.length;
	const start = Math.max(0, Math.min(selLine - Math.floor(body / 2), lines.length - body));
	const view = lines.slice(start, start + body);
	while (view.length < body) view.push("");
	out.write(`\x1b[H\x1b[2J${[...view, ...footer].join("\r\n")}`);
}

function move(delta) {
	const nodeRows = rows.map((r, i) => (r.kind === "node" ? i : -1)).filter((i) => i >= 0);
	const pos = nodeRows.indexOf(selected);
	selected = nodeRows[Math.max(0, Math.min(nodeRows.length - 1, pos + delta))] ?? selected;
}

function run(key) {
	const r = rows[selected];
	const action = r?.node?.actions?.[key];
	if (!action?.cmd?.length) return;
	message = `${action.label ?? key}: ${r.node.label ?? r.node.id}`;
	const [cmd, ...args] = action.cmd;
	const child = spawn(cmd, args, { detached: true, stdio: ["ignore", "ignore", "pipe"], env: { ...process.env, ...panelEnv, PANEL_SOURCE: r.source, PANEL_NODE: r.node.id } });
	let err = "";
	child.stderr.on("data", (d) => (err += d));
	child.on("error", (e) => { message = `error: ${e.message}`; render(); });
	child.on("close", (code) => {
		message = code ? `error: ${err.trim().split("\n").at(-1) || `exit ${code}`}` : "";
		render();
	});
	child.unref();
}

function quit() {
	out.write("\x1b[?1004l\x1b[?25h\x1b[?1049l");
	process.exit(0);
}

// Selection only shows while this pane has focus (tmux focus-events: \e[I in, \e[O out).
let focused = false;
out.write("\x1b[?1049h\x1b[?25l\x1b[?1004h");
process.stdin.setRawMode?.(true);
process.stdin.resume();
process.stdin.setEncoding("utf8");
process.stdin.on("data", (key) => {
	if (key.includes("\x1b[I") || key.includes("\x1b[O")) {
		focused = key.lastIndexOf("\x1b[I") > key.lastIndexOf("\x1b[O");
		return render();
	}
	focused = true; // a key press means we have focus even if the event was missed
	if (key === "q" || key === "\x03") return closeTab("panel"); // kills this pane, next tab shows
	if (key === "\t") return cycle();
	if (key === "j" || key === "\x1b[B") move(1);
	else if (key === "k" || key === "\x1b[A") move(-1);
	else if (key === "g") move(-1e9);
	else if (key === "G") move(1e9);
	else if (key === "\r") run("enter");
	else if (key.length === 1) run(key);
	render();
});
out.on("resize", render);

let pending;
const schedule = () => {
	clearTimeout(pending);
	pending = setTimeout(render, 80);
};
fs.mkdirSync(sourcesDir, { recursive: true });
fs.watch(sourcesDir, { recursive: true }, schedule);
// Elapsed timers tick; also exit once the owner removes the panel directory.
// Owner pi gone (quit, crash, pane closed): take every tab down with it.
setInterval(() => (ownerGone() ? (closeAll(), quit()) : fs.existsSync(dir) ? render() : quit()), 1000);
render();
