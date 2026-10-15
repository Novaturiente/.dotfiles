// Shared swarm logic: file store, agent definitions, tmux process control, formatting.
// Imported by index.ts (inside pi) and ctl.mjs (panel actions, plain node).
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as panel from "../panel/lib.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const EXTENSION = path.join(HERE, "index.ts");
export const CTL = path.join(HERE, "ctl.mjs");
export const STATE = path.join(process.env.XDG_STATE_HOME || path.join(os.homedir(), ".local/state"), "pi-swarm");
export const SOURCE = "swarm";
export const FINISHED = new Set(["done", "failed", "stopped"]);
export const ACTIVE = new Set(["starting", "running", "waiting"]);

const home = (p) => p.replace(/^~(?=\/|$)/, os.homedir());

// ---------- files ----------

export function readJson(file, fallback = undefined) {
	try {
		return JSON.parse(fs.readFileSync(file, "utf8"));
	} catch {
		return fallback;
	}
}

export function writeJson(file, value) {
	fs.mkdirSync(path.dirname(file), { recursive: true });
	const tmp = `${file}.${process.pid}.tmp`;
	fs.writeFileSync(tmp, JSON.stringify(value, null, 1));
	fs.renameSync(tmp, file);
}

export const rootDir = (root) => path.join(STATE, root);
export const agentDir = (root, id) => path.join(rootDir(root), "agents", id);
const f = (root, id, name) => path.join(agentDir(root, id), name);

/** Child-owned state (state.json) and parent-owned control (ctl.json) are separate files so writers never race. */
export function updateState(root, id, patch) {
	const file = f(root, id, "state.json");
	writeJson(file, { ...readJson(file, {}), ...patch, updatedAt: Date.now() });
}
export function updateCtl(root, id, patch) {
	const file = f(root, id, "ctl.json");
	writeJson(file, { ...readJson(file, {}), ...patch });
}

export function record(root, id) {
	const meta = readJson(f(root, id, "meta.json"));
	if (!meta) return undefined;
	const state = readJson(f(root, id, "state.json"), {});
	const ctl = readJson(f(root, id, "ctl.json"), {});
	let status;
	if (ctl.status === "stopped" || ctl.status === "failed" || ctl.status === "queued") status = ctl.status;
	else if (!state.updatedAt || (ctl.launchedAt && state.updatedAt < ctl.launchedAt)) status = ctl.status ?? "queued";
	else status = state.status ?? "starting";
	return { id, meta, state, ctl, status };
}

export function listIds(root) {
	try {
		return fs.readdirSync(path.join(rootDir(root), "agents"));
	} catch {
		return [];
	}
}

export const records = (root) => listIds(root).map((id) => record(root, id)).filter(Boolean);
export const childrenOf = (root, parent) => records(root).filter((r) => r.meta.parent === parent);
export const subtree = (root, id) => records(root).filter((r) => r.id === id || r.id.startsWith(`${id}.`));

export function readResult(root, id) {
	try {
		return fs.readFileSync(f(root, id, "result.md"), "utf8");
	} catch {
		return "";
	}
}

export function readActivity(root, id, limit = 10) {
	try {
		return fs.readFileSync(f(root, id, "activity.jsonl"), "utf8").trim().split("\n").filter(Boolean).slice(-limit).map((l) => JSON.parse(l));
	} catch {
		return [];
	}
}

export function questions(root, id) {
	const dir = f(root, id, "questions");
	if (!fs.existsSync(dir)) return [];
	return fs.readdirSync(dir).sort().map((name) => ({
		qid: name.replace(/\.json$/, ""),
		...readJson(path.join(dir, name), {}),
		answered: fs.existsSync(f(root, id, `answers/${name.replace(/\.json$/, ".md")}`)),
	}));
}

/** Allocate the next child id under parent ("main" → a1, a2; "a1" → a1.1). */
export function allocateId(root, parent) {
	const prefix = parent === "main" ? "a" : `${parent}.`;
	fs.mkdirSync(path.join(rootDir(root), "agents"), { recursive: true });
	const taken = listIds(root).filter((id) => id.startsWith(prefix) && !id.slice(prefix.length).includes(".")).map((id) => Number(id.slice(prefix.length))).filter(Number.isFinite);
	for (let n = Math.max(0, ...taken) + 1; ; n++) {
		try {
			fs.mkdirSync(agentDir(root, `${prefix}${n}`));
			return `${prefix}${n}`;
		} catch (e) {
			if (e.code !== "EEXIST") throw e;
		}
	}
}

// ---------- config and agent definitions ----------

export function config() {
	const c = readJson(path.join(HERE, "config.json"), {});
	return {
		...c,
		agentDirs: (c.agentDirs ?? []).map(home),
		skillDirs: (c.skillDirs ?? []).map(home),
		childExtensions: (c.childExtensions ?? []).map(home),
		toolExtensions: Object.fromEntries(Object.entries(c.toolExtensions ?? {}).map(([k, v]) => [k, home(v)])),
	};
}

/** Minimal frontmatter: `key: value`, `key: a, b`, and `- item` lists. */
export function parseFrontmatter(text) {
	const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
	if (!m) return { fm: {}, body: text };
	const fm = {};
	let last;
	for (const line of m[1].split(/\r?\n/)) {
		const item = line.match(/^\s+-\s+(.*)$/);
		if (item && last) {
			fm[last] = [...(Array.isArray(fm[last]) ? fm[last] : []), item[1].trim()];
			continue;
		}
		const kv = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/);
		if (!kv) continue;
		last = kv[1];
		fm[last] = kv[2].trim().replace(/^["']|["']$/g, "");
	}
	return { fm, body: m[2].trim() };
}

const list = (v) => (Array.isArray(v) ? v : typeof v === "string" && v ? v.split(",") : []).map((s) => s.trim()).filter(Boolean);
const bool = (v, dflt) => (v === undefined || v === "" ? dflt : String(v) === "true");

export function loadAgents() {
	const agents = new Map();
	const walk = (dir) => {
		let entries = [];
		try {
			entries = fs.readdirSync(dir, { withFileTypes: true });
		} catch {
			return;
		}
		for (const e of entries) {
			const p = path.join(dir, e.name);
			if (e.isDirectory()) walk(p);
			else if (e.name.endsWith(".md")) {
				const { fm, body } = parseFrontmatter(fs.readFileSync(p, "utf8"));
				if (!fm.name || agents.has(fm.name)) continue;
				agents.set(fm.name, {
					name: fm.name,
					description: fm.description ?? "",
					group: path.relative(dir, path.dirname(p)) || path.basename(dir),
					tools: list(fm.tools),
					extensions: list(fm.extensions).map(home),
					skills: list(fm.skills),
					model: fm.model || undefined,
					thinking: fm.thinking || undefined,
					replacePrompt: fm.systemPromptMode === "replace",
					projectContext: bool(fm.inheritProjectContext, true),
					globalContext: bool(fm.inheritGlobalContext, false),
					body,
					file: p,
				});
			}
		}
	};
	for (const dir of config().agentDirs) walk(dir);
	return agents;
}

function resolveSkill(name, dirs) {
	for (const dir of dirs) {
		const direct = path.join(dir, name, "SKILL.md");
		if (fs.existsSync(direct)) return path.dirname(direct);
		if (path.basename(dir) !== "node_modules" || !fs.existsSync(dir)) continue;
		// npm root: packages ship skills under <pkg>/skills/<name>/
		for (const pkg of fs.readdirSync(dir)) {
			const pkgs = pkg.startsWith("@") ? fs.readdirSync(path.join(dir, pkg)).map((s) => path.join(pkg, s)) : [pkg];
			for (const p of pkgs) {
				const candidate = path.join(dir, p, "skills", name, "SKILL.md");
				if (fs.existsSync(candidate)) return path.dirname(candidate);
			}
		}
	}
	return undefined;
}

const globMatch = (pattern, name) => (pattern.endsWith("*") ? name.startsWith(pattern.slice(0, -1)) : pattern === name);

// Must not contain anything per-child (id, parent, task): identical system prompts let sibling
// subagents of the same agent type share the prompt cache. Per-child facts go in identity().
function reportRules(canSpawn) {
	return [
		`# Swarm subagent`,
		`You are a background subagent; nobody watches your stream. Your id and parent are in the first message.`,
		`- Your final assistant message of every run is forwarded verbatim to your parent as your report. Make it self-contained:`,
		`  first line = outcome; then findings/changes with file:line; validation you ran;`,
		`  "Not checked:" what you did not verify or assumed (write "Not checked: nothing" only if true); blockers or open questions.`,
		`  No preamble. Stay under ~300 words unless the task asks for more; write long output to a file and give its path.`,
		`- If a decision blocks you and has no clear default, call ask_parent. Otherwise decide and note it in the report.`,
		`- Other subagents may work in the same files. Edits to a file another subagent is changing are blocked;`,
		`  then work on other files, or ask_parent. Never work around a block with bash or a different path.`,
		canSpawn
			? `- You may delegate independent parts with the swarm tool. Your children cannot delegate further. Give them non-overlapping files. Wait for them before your final report.`
			: `- You cannot spawn subagents.`,
	].join("\n");
}

const identity = (meta, maxDepth) =>
	`[swarm] You are subagent ${meta.id} (agent: ${meta.agent ?? "general"}), depth ${meta.depth}/${maxDepth}, spawned by ${meta.parent}.`;

const CONTEXT_NAMES = ["AGENTS.override.md", "AGENTS.md", "AGENTS.MD", "CLAUDE.md", "CLAUDE.MD"];
const AGENT_DIR = path.join(os.homedir(), ".pi/agent");

/** Context files pi would load (first match per folder), split by global/project, as one prompt block. */
export function contextBlock(cwd, { global, project }) {
	const pick = (dir) => CONTEXT_NAMES.map((n) => path.join(dir, n)).find((f) => fs.existsSync(f));
	const files = [];
	if (global) files.push(pick(AGENT_DIR));
	if (project) {
		const dirs = [];
		for (let d = path.resolve(cwd); ; d = path.dirname(d)) {
			if (d !== AGENT_DIR) dirs.unshift(d);
			if (d === path.dirname(d)) break;
		}
		files.push(...dirs.map(pick));
	}
	const parts = files.filter(Boolean).map((f) => `## ${f}\n\n${fs.readFileSync(f, "utf8").trim()}`);
	return parts.length ? `# Project context\n\n${parts.join("\n\n")}` : "";
}

// ---------- file claims: siblings must not edit the same file at once ----------

const claimFile = (root, file) => path.join(rootDir(root), "claims", `${Buffer.from(file).toString("base64url")}.json`);

/** Drop every claim `id` holds (its run settled; a resumed run claims again on its next edit). */
export function releaseClaims(root, id) {
	const dir = path.join(rootDir(root), "claims");
	// Children still at work keep the files their parent claimed for them.
	if (!fs.existsSync(dir) || subtree(root, id).some((r) => r.id !== id && !FINISHED.has(r.status) && r.status !== "queued")) return;
	for (const f of fs.readdirSync(dir)) if (readJson(path.join(dir, f))?.id === id) fs.rmSync(path.join(dir, f), { force: true });
}

/** Real path, so a symlinked and a direct path to one file are the same claim. */
export function realFile(file) {
	try {
		return fs.realpathSync(file);
	} catch {
		try {
			return path.join(fs.realpathSync(path.dirname(file)), path.basename(file));
		} catch {
			return file; // new folder: nobody else can hold it under another name yet
		}
	}
}

/**
 * Who else is changing `file`: the record of a still-active agent that claimed it and is not an
 * ancestor of `id` (a parent's claim passes down to the children it delegated to). `claim` = take
 * it when free. Agents release by finishing; "main" never claims, it only checks.
 */
export function claimHolder(root, id, file, claim) {
	const cf = claimFile(root, file);
	const owner = readJson(cf)?.id;
	const inherited = owner && id !== "main" && id.startsWith(`${owner}.`);
	if (owner && owner !== id && !inherited) {
		// Held while the owner or anything it delegated to is still at work.
		const busy = activeIn(root, owner);
		if (busy) return busy;
	}
	// Keep an ancestor's claim: overwriting it would free the file when this child finishes
	// while the ancestor still works on it.
	if (claim && owner !== id && !inherited) writeJson(cf, { id, file, at: Date.now() });
	return undefined;
}

const activeIn = (root, id) => subtree(root, id).find((r) => !FINISHED.has(r.status) && r.status !== "queued");

/** MCP servers a child may start: the agent's mcp:<server> tools plus the spawner's `mcp` list. */
export function mcpServers(meta, def = meta.agent ? loadAgents().get(meta.agent) : undefined) {
	const fromTools = (def?.tools ?? []).filter((t) => t.startsWith("mcp:")).map((t) => t.slice(4).split("/")[0]);
	return [...new Set([...fromTools, ...(meta.mcp ?? [])])];
}

/** argv for the child's pi process. */
export function piArgs(root, id, { message, resume } = {}) {
	const cfg = config();
	const meta = readJson(f(root, id, "meta.json"));
	const def = meta.agent ? loadAgents().get(meta.agent) : undefined;
	const servers = mcpServers(meta, def);
	const tools = [...(def?.tools ?? [])];
	if (tools.length) for (const s of meta.mcp ?? []) tools.push(`mcp:${s}`);
	// Each MCP server is a process (serena alone is hundreds of MB): start none unless asked for.
	const exts = [...cfg.childExtensions, ...(def?.extensions ?? [])].filter((e) => servers.length || !(e === "builtin:mcp" || e.endsWith("project-mcp.ts")));
	for (const t of tools) for (const [pat, ext] of Object.entries(cfg.toolExtensions)) if (globMatch(pat, t)) exts.push(ext);
	exts.push(EXTENSION);

	const args = ["--no-extensions", "--no-skills", "--no-prompt-templates", ...(servers.length ? [] : ["--no-mcp"])];
	for (const e of [...new Set(exts)]) args.push("-e", e);
	const model = meta.model ?? def?.model ?? cfg.defaultModel;
	const thinking = meta.thinking ?? def?.thinking;
	if (model) args.push("--model", model);
	if (thinking) args.push("--thinking", thinking);
	if (tools.length) {
		const mapped = tools.map((t) => (t.startsWith("mcp:") ? `mcp__${t.slice(4).replace(/\//g, "__")}*` : t));
		if (tools.some((t) => t.startsWith("mcp:"))) mapped.push("codemode");
		mapped.push("ask_parent");
		if (meta.depth < cfg.maxDepth) mapped.push("swarm");
		args.push("--tools", [...new Set(mapped)].join(","));
	}
	for (const s of def?.skills ?? []) {
		const dir = resolveSkill(s, cfg.skillDirs);
		if (dir) args.push("--skill", dir);
	}
	// Context files are added by hand so the global AGENTS.md (the user's own rules, written for the
	// main agent) can be left out while the project's files stay.
	args.push("--no-context-files");
	if (def?.replacePrompt && def.body) args.push("--system-prompt", def.body);
	else if (def?.body) args.push("--append-system-prompt", def.body);
	const context = contextBlock(meta.cwd, { global: def?.globalContext ?? false, project: def?.projectContext ?? true });
	if (context) args.push("--append-system-prompt", context);
	args.push("--append-system-prompt", reportRules(meta.depth < cfg.maxDepth));

	const sessionFile = readJson(f(root, id, "state.json"), {}).sessionFile;
	if (resume && sessionFile && fs.existsSync(sessionFile)) args.push("--session", sessionFile);
	else if (meta.context === "fork" && meta.parentSessionFile) args.push("--fork", meta.parentSessionFile, "--session-dir", f(root, id, "session"));
	else args.push("--session-dir", f(root, id, "session"));
	args.push("--name", `${id} ${meta.agent ?? "general"}`);
	// A resumed pi with no prompt would sit idle in "starting" and hold a concurrency slot.
	args.push("--", message ?? (resume ? "Continue where you left off, then give your final report." : `${identity(meta, cfg.maxDepth)}\n\n${meta.task}`));
	return args;
}

// ---------- tmux ----------

export const tmux = (...args) => {
	try {
		return execFileSync("tmux", args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
	} catch (e) {
		// Never echo the command: launch scripts and args can be huge or carry secrets.
		throw new Error(`tmux ${args[0]}: ${String(e.stderr ?? "").trim() || "failed"}`);
	}
};
const shq = (v) => `'${String(v).replaceAll("'", `'\\''`)}'`;
export const sessionName = (root) => `swarm-${root.slice(0, 8)}`;

export function livePanes() {
	try {
		return new Set(tmux("list-panes", "-a", "-F", "#{pane_id}").split("\n").filter(Boolean));
	} catch {
		return new Set();
	}
}

const HIDDEN_ENV = /^(TMUX|TMUX_PANE|PI_SWARM_.*|PI_PANEL_.*)$/;

/** Start (or restart) the child's pi in a window of the hidden swarm session. */
export function launch(root, id, opts = {}) {
	const meta = readJson(f(root, id, "meta.json"));
	const env = Object.entries(process.env).filter(([k, v]) => v !== undefined && !HIDDEN_ENV.test(k)).map(([k, v]) => `${k}=${v}`);
	const owner = meta.ownerPane; // not TMUX_PANE: ctl.mjs runs from the panel's pane
	const ours = {
		PI_SWARM_ROOT: root,
		PI_SWARM_ID: id,
		PI_SWARM_DEPTH: String(meta.depth),
		PI_SWARM_PARENT: meta.parent,
		PI_MCP_ONLY: mcpServers(meta).join(","), // read by project-mcp.ts
		...(owner ? { PI_SWARM_OWNER: owner } : {}),
		...panel.panelEnv(),
	};
	// Env and args go through a private one-shot script: tmux caps command length, and secrets in
	// argv would show in `ps` for every local user. The script deletes itself before pi starts.
	const script = f(root, id, "run.sh");
	const exports = [...env.filter((kv) => /^[A-Za-z_][A-Za-z0-9_]*=/.test(kv)), ...Object.entries(ours).map(([k, v]) => `${k}=${v}`)].map((kv) => {
		const i = kv.indexOf("=");
		return `export ${kv.slice(0, i)}=${shq(kv.slice(i + 1))}`;
	});
	fs.writeFileSync(script, ['rm -f "$0"', ...exports, `exec pi ${piArgs(root, id, opts).map(shq).join(" ")}`, ""].join("\n"), { mode: 0o600 });
	const argv = ["/usr/bin/env", "-i", "/bin/sh", script];
	const name = `${id}-${meta.agent ?? "general"}`;
	const session = sessionName(root);
	const window = ["-d", "-n", name, "-c", meta.cwd, "-P", "-F", "#{pane_id}", ...argv];
	let pane;
	try {
		pane = tmux("new-window", "-t", `=${session}:`, ...window);
	} catch {
		try {
			pane = tmux("new-session", "-s", session, "-x", "220", "-y", "50", ...window);
		} catch {
			pane = tmux("new-window", "-t", `=${session}:`, ...window); // lost a race creating the session
		}
	}
	updateCtl(root, id, { status: "starting", pane, launchedAt: Date.now(), error: null, reaped: false, exitedAt: null });
	publishNode(root, id);
	return pane;
}

export function killPane(pane) {
	try {
		tmux("kill-pane", "-t", pane);
	} catch {}
}

/** Stop an agent and its whole subtree. */
export function stop(root, id, reason = "stopped") {
	const stopped = [];
	for (const r of subtree(root, id)) {
		if (FINISHED.has(r.status) && !(r.ctl.pane && livePanes().has(r.ctl.pane))) continue;
		if (r.ctl.pane) killPane(r.ctl.pane);
		updateCtl(root, r.id, { status: r.status === "done" ? "done" : "stopped", error: r.status === "done" ? r.ctl.error : reason, reaped: true });
		publishNode(root, r.id);
		stopped.push(r.id);
	}
	return stopped;
}

/** Join the child's pane beside the owner pane, or send it back to the hidden session. */
export function toggleOpen(root, id) {
	const r = record(root, id);
	if (!r) throw new Error(`unknown agent ${id}`);
	const pane = r.ctl.pane;
	if (!pane || !livePanes().has(pane)) throw new Error(`${id} is not running (resume it first)`);
	const session = sessionName(root);
	const where = tmux("display", "-p", "-t", pane, "#{session_name}");
	if (where !== session) {
		tmux("break-pane", "-d", "-s", pane, "-n", `${id}-${r.meta.agent ?? "general"}`, "-t", `=${session}:`);
		const pp = panel.panelPane();
		if (pp) tmux("resize-pane", "-t", pp, "-x", String(panel.WIDTH));
		return "closed";
	}
	const owner = r.meta.ownerPane;
	if (!owner || !livePanes().has(owner)) throw new Error("owner pane is gone");
	// Only one subagent beside the main pane at a time.
	for (const other of records(root)) {
		const p = other.ctl.pane;
		if (other.id !== id && p && livePanes().has(p) && tmux("display", "-p", "-t", p, "#{session_name}") !== session) {
			tmux("break-pane", "-d", "-s", p, "-n", `${other.id}-${other.meta.agent ?? "general"}`, "-t", `=${session}:`);
		}
	}
	tmux("join-pane", "-h", "-s", pane, "-t", owner);
	// join-pane's -l is unreliable next to other side panes: pin the panel, then split main/child evenly.
	const pp = panel.panelPane();
	if (pp) tmux("resize-pane", "-t", pp, "-x", String(panel.WIDTH));
	const total = Number(tmux("display", "-p", "-t", owner, "#{pane_width}")) + Number(tmux("display", "-p", "-t", pane, "#{pane_width}"));
	tmux("resize-pane", "-t", pane, "-x", String(Math.floor(total / 2)));
	return "opened";
}

// ---------- formatting ----------

export function duration(ms) {
	const s = Math.max(0, Math.round(ms / 1000));
	if (s < 60) return `${s}s`;
	if (s < 3600) return `${Math.floor(s / 60)}m${String(s % 60).padStart(2, "0")}s`;
	return `${Math.floor(s / 3600)}h${String(Math.floor((s % 3600) / 60)).padStart(2, "0")}m`;
}
const k = (n) => (n >= 1000 ? `${Math.round(n / 1000)}k` : String(n ?? 0));
export const ICON = { queued: "○", starting: "◐", running: "●", waiting: "?", done: "✓", failed: "✗", stopped: "■" };

export function stats(r, live = true) {
	const s = r.state;
	const parts = [];
	const t = activeTime(s, ACTIVE.has(r.status));
	if (live && (t.ms || t.since)) parts.push(duration(t.ms + (t.since ? Date.now() - t.since : 0)));
	if (s.ctxTokens) parts.push(`ctx ${k(s.ctxTokens)}`);
	if (s.cost) parts.push(`$${s.cost.toFixed(2)}`);
	return parts.join(" ");
}

export function oneLine(r) {
	const now = r.status === "running" && r.state.tool ? ` · ${r.state.tool}` : "";
	const err = r.ctl.error && r.status !== "done" ? ` · ${r.ctl.error}` : "";
	return `${r.id} ${r.meta.agent ?? "general"} ${ICON[r.status] ?? "•"} ${r.status} ${stats(r)}${now}${err} — ${summary(r.meta)}`;
}

/** Short purpose line: the spawner's title, else the task's first sentence. */
export function summary(meta) {
	const s = (meta.title || meta.task.split(/(?<=[.!?])\s/)[0]).replace(/\s+/g, " ").trim();
	return s.length > 70 ? `${s.slice(0, 69)}…` : s;
}

// Nerd Font glyphs: agent groups (dirs under ~/.pi/agent/agents) and the metrics line.
const GROUP_ICON = {
	development: ["\u{F0169}", 36], security: ["\u{F0483}", 31], "data-ai": ["\u{F09D1}", 35], infrastructure: ["\u{F048B}", 34],
	"quality-testing": ["\u{F0668}", 32], business: ["\u{F00D6}", 33], specialization: ["\u{F04CE}", 33],
};
const GENERAL_ICON = ["\u{F06A9}", 37];
const paint = ([g, c]) => `\x1b[${c}m${g}\x1b[0m`;

/** Active time so far: closed runs plus the open one. */
export function activeTime(s, live = true) {
	return { ms: s.activeMs ?? 0, since: live && s.activeSince ? s.activeSince : undefined };
}

export function publishNode(root, id) {
	if (!panel.panelDir()) return;
	const r = record(root, id);
	if (!r) return;
	const s = r.state;
	const ctl = (cmd) => [process.execPath, CTL, cmd, root, id];
	const metrics = [s.ctxTokens && `\uf1c0 ${k(s.ctxTokens)}`, s.tools && `\uf0ad ${s.tools}`, s.cost && `$${s.cost.toFixed(2)}`].filter(Boolean).join("  ");
	const now = r.status === "running" && s.tool ? `\x1b[33m\uf120\x1b[0m ${s.tool}` : r.status === "waiting" ? "\x1b[35m\uf128\x1b[0m asking parent" : "";
	const err = r.ctl.error && !["done", "running"].includes(r.status) ? `\x1b[31m\uf071\x1b[0m ${r.ctl.error}` : "";
	panel.setSource(SOURCE, { title: "", order: 10, newestFirst: true }); // no header: the main row heads the tree
	panel.publish(SOURCE, {
		id,
		parent: r.meta.parent, // "main" is the root node publishMain() writes
		label: `${paint(GROUP_ICON[r.meta.group] ?? GENERAL_ICON)} ${r.meta.agent ?? "general"}`,
		tag: id,
		status: r.status,
		time: activeTime(s, ACTIVE.has(r.status)),
		detail: [summary(r.meta), now || err, metrics],
		actions: {
			enter: { label: "open/close", cmd: ctl("open") },
			r: { label: "result", cmd: ctl("read") },
			x: { label: "stop", cmd: ctl("stop") },
			R: { label: "resume", cmd: ctl("resume") },
		},
	});
}

/** Root of the tree: the user's pi session, with totals for everything under it. */
export function publishMain(root) {
	if (!panel.panelDir()) return;
	const all = records(root);
	if (!all.length) return;
	const running = all.filter((r) => ACTIVE.has(r.status)).length;
	const cost = all.reduce((sum, r) => sum + (r.state.cost ?? 0), 0);
	const failed = all.filter((r) => r.status === "failed").length;
	const node = {
		id: "main",
		label: "main",
		icon: ["\uf2bd", 34],
		status: running ? "running" : "idle",
		detail: [[`${all.length} agents`, running && `\x1b[33m${running} running\x1b[0m`, failed && `\x1b[31m${failed} failed\x1b[0m`, `$${cost.toFixed(2)}`].filter(Boolean).join(" · ")],
	};
	const key = JSON.stringify(node);
	if (key === lastMain) return; // called every tick; only write on change
	lastMain = key;
	panel.publish(SOURCE, node);
}
let lastMain = "";
