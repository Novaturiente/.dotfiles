// Generic tmux side panel shared by pi extensions. One pane per top-level pi pane.
// Any extension publishes nodes as JSON files; viewer.mjs renders them as a tree.
// Contract: see README.md in this directory.
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const VIEWER = fileURLToPath(new URL("./viewer.mjs", import.meta.url));
const BASE = path.join(process.env.XDG_RUNTIME_DIR || os.tmpdir(), "pi-panel");

const tmux = (...args) => execFileSync("tmux", args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();

/** Pane the panel sits beside. Nested pi processes inherit it through PI_PANEL_OWNER. */
export function ownerPane() {
	return process.env.PI_PANEL_OWNER || process.env.TMUX_PANE;
}

/** Panel directory for this pi process, or undefined outside tmux. */
export function panelDir() {
	if (process.env.PI_PANEL_DIR) return process.env.PI_PANEL_DIR;
	const pane = process.env.TMUX_PANE;
	if (!pane || !process.env.TMUX) return undefined;
	const server = process.env.TMUX.split(",")[1] ?? "0";
	return path.join(BASE, `${server}-${pane.replace("%", "")}`);
}

/** Env to pass to child processes so they publish into the same panel. */
export function panelEnv() {
	const dir = panelDir();
	const owner = ownerPane();
	return dir && owner ? { PI_PANEL_DIR: dir, PI_PANEL_OWNER: owner } : {};
}

const file = (source, id) => path.join(panelDir(), "sources", source, `${encodeURIComponent(id)}.json`);

function writeAtomic(target, value) {
	fs.mkdirSync(path.dirname(target), { recursive: true });
	const tmp = `${target}.${process.pid}.tmp`;
	fs.writeFileSync(tmp, JSON.stringify(value));
	fs.renameSync(tmp, target);
}

/** Describe a source (section header). order: lower first. */
/** `newestFirst`: list top-level nodes in reverse order (latest at the top). */
export function setSource(source, { title = source, order = 50, newestFirst = false } = {}) {
	if (!panelDir()) return;
	writeAtomic(path.join(panelDir(), "sources", source, "_source.json"), { title, order, newestFirst });
}

/**
 * Create or replace a node.
 * node: { id, parent?, label, status?, detail?, startedAt?, order?, actions?: { [key]: { label, cmd: string[] } } }
 * Action key "enter" is bound to Enter; any other single-character key is bound to itself.
 */
export function publish(source, node) {
	if (!panelDir()) return;
	writeAtomic(file(source, node.id), { ...node, updatedAt: Date.now() });
}

export function remove(source, id) {
	if (!panelDir()) return;
	fs.rmSync(file(source, id), { force: true });
}

export function clearSource(source) {
	if (!panelDir()) return;
	fs.rmSync(path.join(panelDir(), "sources", source), { recursive: true, force: true });
}


// ---------- tabs: one right-hand slot per owner pane ----------
// Each tab is a pane (viewer, file tree, ...). The visible one sits beside the owner pane; the
// others wait in windows of the hidden session PARK, keeping their state. Highest priority wins
// when a tab opens; closing the visible tab shows the next one.

export const WIDTH = 40;
const PARK = "pi-panels";

function paneAlive(pane) {
	try {
		return tmux("display", "-p", "-t", pane, "#{pane_id}") === pane;
	} catch {
		return false;
	}
}

const windowOf = (pane) => tmux("display", "-p", "-t", pane, "#{window_id}");
const tabFile = (name) => path.join(panelDir(), "tabs", `${name}.json`);

/** Open tabs, highest priority first. Tabs whose pane died are dropped. */
export function tabs() {
	const dir = panelDir();
	if (!dir) return [];
	const tdir = path.join(dir, "tabs");
	if (!fs.existsSync(tdir)) return [];
	const out = [];
	for (const f of fs.readdirSync(tdir).filter((f) => f.endsWith(".json"))) {
		let t;
		try {
			t = JSON.parse(fs.readFileSync(path.join(tdir, f), "utf8"));
		} catch {
			continue; // half-written by another process; next call sees it
		}
		if (paneAlive(t.pane)) out.push(t);
		else fs.rmSync(path.join(tdir, f), { force: true });
	}
	return out.sort((a, b) => b.priority - a.priority || a.name.localeCompare(b.name));
}

export const tab = (name) => tabs().find((t) => t.name === name);

/** The tab currently beside the owner pane. */
export function visibleTab() {
	const owner = ownerPane();
	if (!owner || !paneAlive(owner)) return undefined;
	const win = windowOf(owner);
	return tabs().find((t) => windowOf(t.pane) === win);
}

function withLock(fn) {
	const lock = path.join(panelDir(), "tabs.lock");
	try {
		fs.mkdirSync(lock);
	} catch {
		// Another process holds it; a lock older than 5 s is from a crash.
		if (Date.now() - fs.statSync(lock).mtimeMs < 5000) return undefined;
	}
	try {
		return fn();
	} finally {
		fs.rmSync(lock, { recursive: true, force: true });
	}
}

/**
 * Open tab `name` running `cmd` (argv) unless it is open; show it when nothing is shown or it
 * outranks the shown tab. The tab's process gets PI_PANEL_DIR / PI_PANEL_OWNER in its env.
 * Returns the tab's pane id.
 */
export function openTab(name, { title = name, priority = 50, cmd, width = WIDTH }) {
	const dir = panelDir();
	const owner = ownerPane();
	if (!dir || !owner) return undefined;
	fs.mkdirSync(path.join(dir, "tabs"), { recursive: true });
	fs.writeFileSync(path.join(dir, "owner"), owner);
	// The pi running in the owner pane owns the slot (subagents and ctl.mjs only publish into it).
	if (process.env.TMUX_PANE === owner && !process.env.PI_SWARM_ID) fs.writeFileSync(path.join(dir, "ownerpid"), String(process.pid));
	return withLock(() => {
		let t = tab(name);
		if (!t) {
			try {
				tmux("has-session", "-t", `=${PARK}`);
			} catch {
				tmux("new-session", "-d", "-s", PARK, "-n", "keep", "tail", "-f", "/dev/null");
			}
			const env = ["-e", `PI_PANEL_DIR=${dir}`, "-e", `PI_PANEL_OWNER=${owner}`];
			const pane = tmux("new-window", "-d", "-t", `=${PARK}:`, ...env, "-P", "-F", "#{pane_id}", ...cmd);
			tmux("set", "-p", "-t", pane, "@slot", name);
			t = { name, title, priority, width: String(width), pane };
			fs.writeFileSync(tabFile(name), JSON.stringify(t));
		}
		const cur = visibleTab();
		if (!cur || (cur.name !== name && priority >= cur.priority)) show(t, cur, owner);
		return t.pane;
	});
}

function show(t, cur, owner) {
	if (cur) tmux("swap-pane", "-d", "-s", t.pane, "-t", cur.pane);
	else tmux("join-pane", "-d", "-h", "-s", t.pane, "-t", owner);
	tmux("resize-pane", "-t", t.pane, "-x", t.width);
}

/** Bring an open tab beside the owner pane. */
export function showTab(name) {
	const owner = ownerPane();
	const t = tab(name);
	if (!t || !owner) return;
	const cur = visibleTab();
	if (cur?.name !== name) show(t, cur, owner);
}

/** Close a tab; if it was shown, the highest-priority remaining tab takes its place. */
export function closeTab(name) {
	const t = tab(name);
	if (!t) return;
	const owner = ownerPane();
	const next = tabs().find((o) => o.name !== name);
	if (owner && next && visibleTab()?.name === name) show(next, t, owner);
	tmux("kill-pane", "-t", t.pane);
	fs.rmSync(tabFile(name), { force: true });
}

/** True once the owning pi exited (even by crash or kill, when no shutdown hook ran) or its pane is gone. */
export function ownerGone() {
	const owner = ownerPane();
	if (!owner || !paneAlive(owner)) return true;
	try {
		process.kill(Number(fs.readFileSync(path.join(panelDir(), "ownerpid"), "utf8")), 0);
	} catch (e) {
		return e.code === "ESRCH"; // no pid file yet (ENOENT) or not ours (EPERM): treat as alive
	}
	return false;
}

/** Close every tab without handing the slot on; the calling tab's own pane goes last. */
export function closeAll() {
	const all = tabs();
	fs.rmSync(path.join(panelDir(), "tabs"), { recursive: true, force: true });
	for (const t of all.sort((a) => (a.pane === process.env.TMUX_PANE ? 1 : -1))) {
		try {
			tmux("kill-pane", "-t", t.pane);
		} catch {
			// another tab closed it first
		}
	}
}

/** Show the next tab (Tab key in a tab's TUI). */
export function cycle() {
	const all = tabs();
	const cur = visibleTab();
	if (all.length < 2 || !cur) return;
	showTab(all[(all.findIndex((t) => t.name === cur.name) + 1) % all.length].name);
}

/** One-line tab bar for TUIs: [{title, active}] where active = the tab running in `pane`. */
export const tabBar = (pane) => tabs().map((t) => ({ title: t.title, active: t.pane === pane }));

// ---------- the node viewer is the tab "panel" ----------

/** The viewer's pane id if its tab is open. */
export const panelPane = () => tab("panel")?.pane;

export function ensurePane({ title = "Panel", priority = 20 } = {}) {
	return openTab("panel", { title, priority, cmd: [process.execPath, VIEWER, panelDir() ?? ""], width: WIDTH });
}

/** True when no source (other than `except`) has any node left. */
export function isEmpty(except) {
	const dir = panelDir();
	if (!dir) return true;
	const root = path.join(dir, "sources");
	if (!fs.existsSync(root)) return true;
	return fs
		.readdirSync(root)
		.filter((s) => s !== except)
		.every((s) => fs.readdirSync(path.join(root, s)).every((f) => f === "_source.json"));
}

/** Close the viewer tab but keep the nodes, so ensurePane() shows them again. */
const statusOf = (f) => {
	try {
		return JSON.parse(fs.readFileSync(f, "utf8")).status;
	} catch {
		return "done"; // removed or mid-write: not worth holding the pane open
	}
};

/** True while any node outside `except` is still in progress (not done/failed/stopped). */
export function busy(except) {
	const dir = panelDir();
	const root = dir && path.join(dir, "sources");
	if (!root || !fs.existsSync(root)) return false;
	const idle = new Set(["done", "failed", "stopped", "idle"]);
	return fs
		.readdirSync(root)
		.filter((s) => s !== except)
		.some((s) => fs.readdirSync(path.join(root, s)).some((f) => f !== "_source.json" && !idle.has(statusOf(path.join(root, s, f)))));
}

export const hidePane = () => closeTab("panel");
export const closePane = hidePane;
