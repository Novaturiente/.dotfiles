/**
 * swarm — background subagents, each a full pi process in a hidden tmux window.
 *
 * Roles (one module, chosen by env):
 *  - parent (main pi, and children below maxDepth): `swarm` tool, polls its direct
 *    children's files, forwards their reports as one-line-header [swarm] messages.
 *  - child (PI_SWARM_ID set): writes state/activity/result files, takes inbox
 *    messages, offers `ask_parent`.
 *
 * Cache rule: tools are registered once at load and never toggled; nothing edits the
 * system prompt per turn. Child news only ever appends messages to the transcript.
 * Files: ~/.local/state/pi-swarm/<rootSessionId>/agents/<id>/  (see README.md)
 */
import fs from "node:fs";
import path from "node:path";
import { Type } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import * as panel from "../panel/lib.mjs";
import * as core from "./core.mjs";

const text = (t: string, details?: unknown) => ({ content: [{ type: "text" as const, text: t }], details });
const sleep = (ms: number, signal?: AbortSignal) =>
	new Promise<void>((resolve) => {
		const t = setTimeout(resolve, ms);
		signal?.addEventListener("abort", () => (clearTimeout(t), resolve()), { once: true });
	});

export default function swarm(pi: ExtensionAPI) {
	const cfg = core.config();
	const myId = process.env.PI_SWARM_ID ?? "main";
	const depth = Number(process.env.PI_SWARM_DEPTH ?? 0);
	let root = process.env.PI_SWARM_ROOT;
	let ctx: any;

	if (myId !== "main") registerChild(pi, () => root!, myId);

	// File claims: block an edit/write to a file another active subagent is changing.
	// shortcut: bash writes (sed -i, redirects) are not seen; the report rules forbid that workaround.
	pi.on("tool_call", (e: any, c) => {
		if (!root || !/^(edit|write)$/i.test(e.toolName) || typeof e.input?.path !== "string") return;
		if (myId === "main" && !core.listIds(root).length) return;
		const file = core.realFile(path.resolve(c.cwd, e.input.path));
		const holder = core.claimHolder(root, myId, file, myId !== "main");
		if (!holder) return;
		const how = myId === "main" ? "wait for it (swarm wait) or tell it (swarm send)" : "work on other files, or ask_parent";
		return { block: true, reason: `${file} is being changed by subagent ${holder.id} (${core.summary(holder.meta)}). Do not edit it now; ${how}.` };
	});

	if (depth >= cfg.maxDepth) return;

	// ---------- parent: event detection ----------

	type Event = { r: any; kind: "report" | "end" | "question"; key: string; q?: any };
	const seenFile = (id: string) => path.join(core.agentDir(root!, id), "seen.json");
	const seen = (id: string) => core.readJson(seenFile(id), { run: 0, end: "", questions: [] as string[] });
	const waiting = new Set<string>(); // children a running `wait` call is collecting

	function eventsOf(r: any): Event[] {
		const s = seen(r.id);
		const out: Event[] = [];
		for (const q of core.questions(root!, r.id)) if (!q.answered && !s.questions.includes(q.qid)) out.push({ r, kind: "question", key: q.qid, q });
		if ((r.state.run ?? 0) > s.run) out.push({ r, kind: "report", key: String(r.state.run) });
		else if ((r.status === "failed" || r.status === "stopped") && s.end !== `${r.status}:${r.ctl.launchedAt}`) out.push({ r, kind: "end", key: `${r.status}:${r.ctl.launchedAt}` });
		return out;
	}

	function markSeen(events: Event[]) {
		for (const e of events) {
			const s = seen(e.r.id);
			if (e.kind === "question") s.questions.push(e.key);
			if (e.kind === "report") s.run = Number(e.key);
			if (e.kind === "end") s.end = e.key;
			core.writeJson(seenFile(e.r.id), s);
		}
	}

	function formatEvent(e: Event): string {
		const r = e.r;
		const head = `[swarm] ${r.id} ${r.meta.agent ?? "general"}`;
		if (e.kind === "question") return `${head} asks (${e.key}): ${e.q.question}\n→ answer with swarm reply id=${r.id}`;
		if (e.kind === "end") return `${head} ${core.ICON[r.status]} ${r.status}: ${r.ctl.error ?? "no reason"} ${core.stats(r)}${core.readResult(root!, r.id) ? ` (last report: swarm read id=${r.id})` : ""}`;
		const body = core.readResult(root!, r.id).trim() || "(empty report)";
		const shown = body.length <= cfg.inlineChars ? body : `${body.slice(0, 600)}\n… (${body.length} chars; swarm read id=${r.id})`;
		return `${head} ✓ report${Number(e.key) > 1 ? ` #${e.key}` : ""} ${core.stats(r)}\n${shown}`;
	}

	// ---------- parent: delivery (batched, append-only) ----------

	let pending: Event[] = [];
	let flushTimer: NodeJS.Timeout | undefined;
	function queue(events: Event[]) {
		const fresh = events.filter((e) => !pending.some((p) => p.r.id === e.r.id && p.kind === e.kind && p.key === e.key));
		if (!fresh.length) return;
		pending.push(...fresh);
		flushTimer ??= setTimeout(flush, 1500);
	}
	function flush() {
		flushTimer = undefined;
		const batch = pending.filter((e) => !waiting.has(e.r.id));
		pending = pending.filter((e) => waiting.has(e.r.id));
		const visible = batch.filter((e) => e.kind === "question" || e.r.meta.notify !== "quiet");
		markSeen(batch);
		if (!visible.length) return;
		const wake = visible.some((e) => e.kind === "question" || (e.r.meta.notify ?? "wake") === "wake");
		const message = { customType: "swarm", content: visible.map(formatEvent).join("\n\n"), display: true, details: { ids: visible.map((e) => e.r.id) } };
		let idle = false;
		try {
			idle = ctx?.isIdle?.() ?? false;
		} catch {
			// stale ctx after a session replacement: treat as busy, steer queues safely
		}
		if (!wake) pi.sendMessage(message, { deliverAs: "nextTurn" });
		else if (idle) pi.sendMessage(message, { triggerTurn: true });
		else pi.sendMessage(message, { deliverAs: "steer" });
	}

	// ---------- parent: supervision loop ----------

	function tick() {
		if (!root) return;
		const mine = core.childrenOf(root, myId);
		if (!mine.length) return;
		const live = core.livePanes();
		const now = Date.now();
		for (const r of mine) {
			const alive = r.ctl.pane && live.has(r.ctl.pane);
			if (core.ACTIVE.has(r.status) && !alive && now - (r.ctl.launchedAt ?? 0) > 3000) {
				core.updateCtl(root, r.id, { status: "failed", error: "process exited" });
				core.publishNode(root, r.id);
			} else if (r.status === "starting" && alive && now - (r.ctl.launchedAt ?? now) > 120_000) {
				core.stop(root, r.id, "did not start within 2m");
			} else if (r.status === "running" && !r.state.tool && now - (r.state.updatedAt ?? now) > cfg.stallMin * 60_000) {
				// No tool running and nothing logged: a hung model request or a run that never settles.
				// A long tool call is not a stall; timeoutMin covers that.
				core.stop(root, r.id, `stalled: no activity for ${cfg.stallMin}m`);
			} else if ((r.status === "running" || r.status === "waiting") && r.state.startedAt && now - r.state.startedAt > cfg.timeoutMin * 60_000) {
				core.stop(root, r.id, `timeout after ${cfg.timeoutMin}m`);
			} else if (r.status === "done" && alive && !r.ctl.reaped && now - (r.state.doneAt ?? now) > cfg.reapAfterMin * 60_000) {
				// Free memory; the session file stays, resume relaunches it. Never reap a pane the user has open,
				// or a child whose own children still run (their reports go to it).
				const busyKids = core.subtree(root, r.id).some((d: any) => d.id !== r.id && !core.FINISHED.has(d.status));
				if (!busyKids && core.tmux("display", "-p", "-t", r.ctl.pane, "#{session_name}") === core.sessionName(root)) {
					core.killPane(r.ctl.pane);
					core.updateCtl(root, r.id, { reaped: true });
				}
			}
		}
		// Queue: dependencies first, then the root-wide concurrency cap.
		let running = core.records(root).filter((r: any) => core.ACTIVE.has(r.status)).length;
		for (const r of mine.filter((r: any) => r.status === "queued")) {
			const deps = (r.meta.after ?? []).map((id: string) => core.record(root!, id));
			if (deps.some((d: any) => !d || d.status === "failed" || d.status === "stopped")) {
				core.updateCtl(root, r.id, { status: "failed", error: `dependency ${r.meta.after.join(",")} did not finish` });
				core.publishNode(root, r.id);
				continue;
			}
			if (deps.some((d: any) => d.status !== "done") || running >= cfg.maxConcurrent) continue;
			core.launch(root, r.id);
			running++;
		}
		queue(core.childrenOf(root, myId).filter((r: any) => !waiting.has(r.id)).flatMap(eventsOf));
		if (myId === "main") {
			core.publishMain(root);
			autoHide(now);
		}
	}

	// Hide the panel 5 s after the last subagent finishes; nodes stay, /swarm shows them again.
	let busySeen = false;
	let hideAt = 0;
	function autoHide(now: number) {
		if (core.records(root).some((r: any) => !core.FINISHED.has(r.status))) {
			busySeen = true;
			hideAt = 0;
		} else if (busySeen) {
			hideAt ||= now + 5000;
			if (now < hideAt) return;
			busySeen = false;
			hideAt = 0;
			if (panel.isEmpty(core.SOURCE)) panel.hidePane();
		}
	}

	if (myId === "main")
		pi.registerCommand("swarm", {
			description: "Show or hide the subagent panel",
			handler: async (_args, c) => {
				if (panel.panelPane()) panel.hidePane();
				else if (root && core.listIds(root).length) panel.ensurePane({ title: "Agent" });
				else c.ui.notify("no subagents in this session", "info");
			},
		});

	let loop: NodeJS.Timeout | undefined;
	pi.on("session_start", (_e, c) => {
		ctx = c;
		if (myId === "main") {
			root = c.sessionManager.getSessionId();
			// Children watch this pid and exit once main is gone (crash or kill skip the quit hook).
			fs.mkdirSync(core.rootDir(root), { recursive: true });
			fs.writeFileSync(path.join(core.rootDir(root), "main.pid"), String(process.pid));
			// Resumed session: rebuild panel rows (quit cleared them) so /swarm shows earlier subagents.
			for (const id of core.listIds(root)) core.publishNode(root, id);
			core.publishMain(root);
		}
		clearInterval(loop);
		loop = setInterval(() => {
			try {
				tick();
			} catch (err) {
				console.error(`[swarm] tick: ${(err as Error).message}`);
			}
		}, 1000);
	});
	pi.on("session_shutdown", (e) => {
		clearInterval(loop);
		clearTimeout(flushTimer);
		if (myId !== "main" || e.reason !== "quit" || !root) return;
		// Main pi quits: nothing would read the reports, so end the whole tree.
		for (const r of core.childrenOf(root, "main")) core.stop(root, r.id, "main session quit");
		try {
			core.tmux("kill-session", "-t", `=${core.sessionName(root)}`);
		} catch {
			// session already gone
		}
		panel.clearSource(core.SOURCE);
		if (panel.isEmpty()) panel.closePane();
	});

	// ---------- parent: the tool ----------

	const Str = (description: string) => Type.Optional(Type.String({ description }));
	const Enum = (values: string[], description: string) => Type.Optional(Type.String({ enum: values, description }));
	const ACTIONS = ["agents", "spawn", "list", "status", "log", "read", "send", "reply", "wait", "stop", "resume", "open"];

	function resolveId(id: string | undefined) {
		if (!id) throw new Error("id is required");
		const r = core.record(root!, id);
		if (!r || (myId !== "main" && !id.startsWith(`${myId}.`))) throw new Error(`unknown subagent ${id}`);
		return r;
	}

	function spawnOne(spec: any, c: any, agents: Map<string, any>) {
		if (spec.agent && !agents.has(spec.agent)) throw new Error(`unknown agent "${spec.agent}" (see swarm action=agents)`);
		if (!spec.task?.trim()) throw new Error("task is required");
		const id = core.allocateId(root!, myId);
		const meta = {
			id,
			parent: myId,
			depth: depth + 1,
			agent: spec.agent,
			group: spec.agent ? agents.get(spec.agent).group : undefined,
			task: spec.task,
			title: spec.title,
			mcp: spec.mcp,
			cwd: path.resolve(c.cwd, spec.cwd ?? "."),
			model: spec.model,
			thinking: spec.thinking,
			context: spec.context ?? "fresh",
			notify: spec.notify ?? "wake",
			after: spec.after,
			ownerPane: process.env.PI_SWARM_OWNER || process.env.TMUX_PANE,
			parentSessionFile: c.sessionManager.getSessionFile(),
			createdAt: Date.now(),
		};
		core.writeJson(path.join(core.agentDir(root!, id), "meta.json"), meta);
		core.updateCtl(root!, id, { status: "queued" });
		core.publishNode(root!, id);
		return id;
	}

	pi.registerTool({
		name: "swarm",
		label: "Swarm",
		description:
			"Background subagents; each is a full pi (tools, MCP) in a hidden tmux window. Returns at once; reports arrive by themselves as [swarm] messages, so do not poll.\n" +
			"agents [query]: agent types · spawn agent? task title | tasks[]: start children (opts: cwd, model, thinking, context fresh|fork, notify wake|next|quiet, after[ids], mcp[servers]) · " +
			"list · status id · log id [limit] · read id [offset limit]: full report · send id message [deliver steer|followup] · reply id message: answer its question · " +
			"wait [ids] [until all|any] [timeout s]: block until reports · stop id: kills its subtree · resume id [message] · open id: show/hide its pane next to the user's.",
		promptSnippet: "swarm: run background subagents (full pi each); their reports arrive as [swarm] messages",
		parameters: Type.Object({
			action: Type.String({ enum: ACTIONS }),
			id: Str("subagent id"),
			ids: Type.Optional(Type.Array(Type.String())),
			agent: Str("agent type from action=agents; omit for a general agent"),
			task: Str("complete, self-contained instructions"),
			title: Str("spawn: purpose in ≤6 words, shown in the panel"),
			mcp: Type.Optional(Type.Array(Type.String(), { description: "MCP servers the child needs (e.g. context7); none start otherwise, besides its agent's mcp: tools" })),
			tasks: Type.Optional(Type.Array(Type.Object({ agent: Str(""), task: Type.String(), title: Str(""), mcp: Type.Optional(Type.Array(Type.String())), cwd: Str(""), model: Str("") }), { description: "spawn several at once" })),
			cwd: Str(""),
			model: Str("provider/id[:thinking]; default: the agent file's model, else config defaultModel"),
			thinking: Enum(["off", "minimal", "low", "medium", "high", "xhigh"], ""),
			context: Enum(["fresh", "fork"], "fork = child starts with a copy of this conversation"),
			notify: Enum(["wake", "next", "quiet"], "wake (default): report starts a turn; next: rides along with the next turn; quiet: panel only"),
			after: Type.Optional(Type.Array(Type.String(), { description: "start only after these ids are done" })),
			message: Str(""),
			deliver: Enum(["steer", "followup"], "send: steer = after its current tool calls (default), followup = after its run"),
			until: Enum(["all", "any"], ""),
			timeout: Type.Optional(Type.Number({ description: "wait seconds, default 600" })),
			offset: Type.Optional(Type.Number()),
			limit: Type.Optional(Type.Number()),
			query: Str(""),
		}),
		async execute(_callId, p: any, signal, onUpdate, c) {
			ctx = c;
			if (!root) root = c.sessionManager.getSessionId();
			switch (p.action) {
				case "agents": {
					const q = (p.query ?? "").toLowerCase();
					const rows = [...core.loadAgents().values()]
						.filter((a: any) => !q || `${a.name} ${a.group} ${a.description}`.toLowerCase().includes(q))
						.map((a: any) => `${a.group}/${a.name} — ${a.description.split(/(?<=\.)\s/)[0].slice(0, 110)}${a.model ? ` [${a.model}]` : ""}`);
					return text(rows.length ? rows.join("\n") : "no matching agents; omit agent for a general one");
				}
				case "spawn": {
					const specs = p.tasks?.length ? p.tasks.map((t: any) => ({ ...p, ...t })) : [p];
					if (core.listIds(root).length + specs.length > cfg.maxSpawnsPerRoot) throw new Error(`spawn budget: max ${cfg.maxSpawnsPerRoot} subagents per session`);
					const agents = core.loadAgents();
					const ids = specs.map((s: any) => spawnOne(s, c, agents));
					tick();
					panel.ensurePane({ title: "Agent" });
					const lines = ids.map((id: string) => {
						const r = core.record(root!, id)!;
						return `${id} ${r.meta.agent ?? "general"} ${r.status}`;
					});
					return text(`${lines.join("\n")}\nReports will arrive as [swarm] messages.`, { ids });
				}
				case "list": {
					const rows = core.records(root).filter((r: any) => myId === "main" || r.id.startsWith(`${myId}.`));
					if (!rows.length) return text("no subagents");
					rows.sort((a: any, b: any) => a.id.localeCompare(b.id, undefined, { numeric: true }));
					return text(rows.map((r: any) => `${"  ".repeat(r.meta.depth - depth - 1)}${core.oneLine(r)}`).join("\n"));
				}
				case "status": {
					const r = resolveId(p.id);
					const qs = core.questions(root, r.id).filter((q: any) => !q.answered);
					const act = core.readActivity(root, r.id, 5).map((a: any) => `  ${new Date(a.t).toTimeString().slice(0, 8)} ${a.tool}`);
					return text([
						core.oneLine(r),
						`task: ${r.meta.task.slice(0, 500)}`,
						...qs.map((q: any) => `open question ${q.qid}: ${q.question}`),
						act.length ? `recent:\n${act.join("\n")}` : "",
						`session: ${r.state.sessionFile ?? "-"}`,
					].filter(Boolean).join("\n"));
				}
				case "log": {
					const r = resolveId(p.id);
					const act = core.readActivity(root, r.id, p.limit ?? 15);
					return text(act.map((a: any) => `${new Date(a.t).toTimeString().slice(0, 8)} ${a.tool}`).join("\n") || "no tool calls yet");
				}
				case "read": {
					const r = resolveId(p.id);
					const body = core.readResult(root, r.id);
					if (!body) return text(`${r.id} has no report yet (${r.status})`);
					const off = p.offset ?? 0;
					const lim = p.limit ?? 8000;
					markSeen(eventsOf(r).filter((e) => e.kind === "report"));
					const end = Math.min(body.length, off + lim);
					return text(`${body.slice(off, end)}${end < body.length ? `\n… chars ${off}-${end} of ${body.length}; read again with offset=${end}` : ""}`);
				}
				case "send":
				case "resume": {
					const r = resolveId(p.id);
					const alive = r.ctl.pane && core.livePanes().has(r.ctl.pane);
					if (alive) {
						if (!p.message) throw new Error("message is required");
						const inbox = path.join(core.agentDir(root, r.id), "inbox");
						fs.mkdirSync(inbox, { recursive: true });
						core.writeJson(path.join(inbox, `${Date.now()}.json`), { deliver: p.deliver ?? (p.action === "resume" ? "followup" : "steer"), text: p.message });
						return text(`queued for ${r.id}`);
					}
					if (r.status === "queued") throw new Error(`${r.id} has not started yet`);
					core.launch(root, r.id, { resume: true, message: p.message });
					return text(`${r.id} relaunched from its session${p.message ? " with your message" : ""}`);
				}
				case "reply": {
					const r = resolveId(p.id);
					const q = core.questions(root, r.id).find((q: any) => !q.answered);
					if (!q) throw new Error(`${r.id} has no open question`);
					if (!p.message) throw new Error("message is required");
					fs.mkdirSync(path.join(core.agentDir(root, r.id), "answers"), { recursive: true });
					fs.writeFileSync(path.join(core.agentDir(root, r.id), "answers", `${q.qid}.md`), p.message);
					markSeen([{ r, kind: "question", key: q.qid }]);
					return text(`answered ${r.id} ${q.qid}`);
				}
				case "wait": {
					const until = p.until ?? "all";
					const targets: string[] = p.ids?.length
						? p.ids.map((id: string) => resolveId(id).id)
						: core.childrenOf(root, myId).filter((r: any) => !core.FINISHED.has(r.status) || eventsOf(r).length).map((r: any) => r.id);
					if (!targets.length) return text("nothing to wait for");
					const deadline = Date.now() + Math.min(p.timeout ?? 600, 3600) * 1000;
					const got: Event[] = [];
					for (const id of targets) waiting.add(id);
					try {
						while (!signal?.aborted) {
							tick();
							const rs = targets.map((id) => core.record(root!, id)!);
							const fresh = rs.flatMap(eventsOf).filter((e) => !got.some((g) => g.r.id === e.r.id && g.kind === e.kind && g.key === e.key));
							got.push(...fresh);
							markSeen(fresh);
							const finished = rs.filter((r) => core.FINISHED.has(r.status));
							if (got.some((e) => e.kind === "question")) break;
							if (until === "any" ? got.length > 0 : finished.length === rs.length) break;
							if (Date.now() > deadline) break;
							onUpdate?.(text(`waiting: ${finished.length}/${rs.length} finished`));
							await sleep(1000, signal);
						}
					} finally {
						for (const id of targets) waiting.delete(id);
						pending = pending.filter((e) => !got.some((g) => g.r.id === e.r.id && g.kind === e.kind && g.key === e.key));
					}
					const rest = targets.map((id) => core.record(root!, id)!).filter((r) => !core.FINISHED.has(r.status));
					const tail = rest.length ? `\n\nstill running:\n${rest.map(core.oneLine).join("\n")}` : "";
					const none = rest.length ? "no new reports yet" : "all finished; their reports were already delivered as [swarm] messages";
					return text((got.map(formatEvent).join("\n\n") || none) + tail);
				}
				case "stop": {
					const r = resolveId(p.id);
					const ids = core.stop(root, r.id, "stopped by parent");
					markSeen(ids.map((id: string) => core.record(root!, id)).flatMap((x: any) => eventsOf(x).filter((e) => e.kind === "end")));
					return text(ids.length ? `stopped ${ids.join(", ")}` : `${r.id} was not running`);
				}
				case "open": {
					const r = resolveId(p.id);
					return text(`${r.id} ${core.toggleOpen(root, r.id)}`);
				}
			}
			throw new Error(`unknown action ${p.action}`);
		},
	});
}

// ---------- child side ----------

function registerChild(pi: ExtensionAPI, root: () => string, id: string) {
	const dir = () => core.agentDir(root(), id);
	const parent = process.env.PI_SWARM_PARENT ?? "main";
	let cost = 0;
	let lastText = "";
	let ctx: any;
	let lastPublish = 0;
	let trailing: NodeJS.Timeout | undefined;
	const update = (patch: Record<string, unknown>, force = false) => {
		core.updateState(root(), id, patch);
		const publish = () => {
			clearTimeout(trailing);
			trailing = undefined;
			lastPublish = Date.now();
			core.publishNode(root(), id);
		};
		if (force || Date.now() - lastPublish > 500) publish();
		else trailing ??= setTimeout(publish, 500); // throttled, but the last state always lands
	};
	const run = () => core.readJson(path.join(dir(), "state.json"), {}).run ?? 0;

	const parentAlive = () => {
		const pid = parent === "main" ? Number(core.readJson(path.join(core.rootDir(root()), "main.pid"))) : core.readJson(path.join(core.agentDir(root(), parent), "state.json"), {}).pid;
		try {
			if (pid) process.kill(pid, 0);
			return true; // no pid recorded yet: assume alive
		} catch (e: any) {
			return e.code !== "ESRCH";
		}
	};
	let inboxLoop: NodeJS.Timeout | undefined;
	let orphaned = false; // parent died: the abort below must not record a "done" run
	pi.on("session_start", (_e, c) => {
		ctx = c;
		cost = core.readJson(path.join(dir(), "state.json"), {}).cost ?? 0;
		update({ status: "starting", sessionFile: c.sessionManager.getSessionFile(), pid: process.pid }, true);
		clearInterval(inboxLoop);
		inboxLoop = setInterval(() => {
			// Parent gone: nobody reads reports or reaps this process, so end it (and, in turn, its children).
			if (!parentAlive()) {
				core.releaseClaims(root(), id);
				clearInterval(inboxLoop);
				orphaned = true;
				update({ status: "stopped", error: "parent exited", tool: null, ...clock(false) }, true);
				ctx.abort(); // shutdown() alone waits for the running turn
				ctx.shutdown();
				setTimeout(() => process.exit(0), 5000);
				return;
			}
			const inbox = path.join(dir(), "inbox");
			if (!fs.existsSync(inbox)) return;
			for (const name of fs.readdirSync(inbox).filter((n) => n.endsWith(".json")).sort()) {
				const file = path.join(inbox, name);
				const msg = core.readJson(file);
				fs.rmSync(file, { force: true });
				if (!msg?.text) continue;
				const content = `[from ${parent}] ${msg.text}`;
				let idle = true;
				try {
					idle = ctx.isIdle();
				} catch {
					// stale ctx: plain prompt
				}
				if (idle) pi.sendUserMessage(content);
				else pi.sendUserMessage(content, { deliverAs: msg.deliver === "followup" ? "followUp" : "steer" });
			}
		}, 1000);
	});
	pi.on("session_shutdown", () => clearInterval(inboxLoop));
	// Active time: the clock runs only while a run is working (not queued, waiting on ask_parent or done).
	const clock = (on: boolean) => {
		const s = core.readJson(path.join(dir(), "state.json"), {});
		const ms = (s.activeMs ?? 0) + (s.activeSince ? Date.now() - s.activeSince : 0);
		return { activeMs: ms, activeSince: on ? Date.now() : null };
	};
	pi.on("agent_start", () => update({ status: "running", startedAt: Date.now(), doneAt: null, tool: null, ...clock(true) }, true));
	pi.on("tool_execution_start", (e) => {
		const a = e.args ?? {};
		const arg = String(a.command ?? a.path ?? a.file_path ?? a.pattern ?? a.query ?? a.action ?? JSON.stringify(a)).replace(/\s+/g, " ").slice(0, 80);
		const tool = `${e.toolName}: ${arg}`;
		fs.appendFileSync(path.join(dir(), "activity.jsonl"), `${JSON.stringify({ t: Date.now(), tool })}\n`);
		update({ tool, tools: (core.readJson(path.join(dir(), "state.json"), {}).tools ?? 0) + 1 });
	});
	// Stall check needs "no tool in flight"; tools can run in parallel, so count them.
	let inFlight = 0;
	pi.on("tool_execution_start", () => void inFlight++);
	pi.on("tool_execution_end", () => {
		inFlight = Math.max(0, inFlight - 1);
		if (!inFlight) update({ tool: null });
	});
	pi.on("message_end", (e) => {
		const m: any = e.message;
		if (m?.role !== "assistant" || !m.usage) return;
		cost += m.usage.cost?.total ?? 0;
		update({ cost, ctxTokens: (m.usage.input ?? 0) + (m.usage.cacheRead ?? 0) + (m.usage.cacheWrite ?? 0) + (m.usage.output ?? 0) });
	});
	pi.on("agent_end", (e) => {
		const last: any = [...e.messages].reverse().find((m: any) => m.role === "assistant");
		const t = last?.content?.filter((b: any) => b.type === "text").map((b: any) => b.text).join("\n").trim();
		if (t) lastText = t;
	});
	pi.on("agent_settled", (e) => {
		if (orphaned) return;
		core.releaseClaims(root(), id);
		fs.writeFileSync(path.join(dir(), "result.md"), lastText || "(no final text)");
		update({ status: "done", doneAt: Date.now(), run: run() + 1, aborted: e.aborted, tool: null, ...clock(false) }, true);
	});

	pi.registerTool({
		name: "ask_parent",
		label: "Ask parent",
		// Static text: a per-child description would break the shared prompt cache (tools come first).
		description: "Ask your parent a blocking question and wait for the answer. Only for decisions you cannot default.",
		parameters: Type.Object({ question: Type.String() }),
		async execute(_callId, p: any, signal) {
			const qid = `q${Date.now()}`;
			core.writeJson(path.join(dir(), "questions", `${qid}.json`), { question: p.question, at: Date.now() });
			update({ status: "waiting", ...clock(false) }, true);
			const answer = path.join(dir(), "answers", `${qid}.md`);
			try {
				while (!signal?.aborted) {
					if (fs.existsSync(answer)) return text(`Answer from ${parent}: ${fs.readFileSync(answer, "utf8")}`);
					await sleep(1000, signal);
				}
				throw new Error("aborted while waiting for an answer");
			} finally {
				update({ status: "running", ...clock(true) }, true);
			}
		},
	});
}
