/**
 * Prompt-cache miss tracer. Before each model request, compares the full
 * transcript with the previous request's and logs the first message that
 * changed (a change there invalidates the cached prefix from that point).
 * Also logs per-response cache usage. Log: ~/.pi/agent/cache-trace.jsonl
 *
 * /cache-audit: finds cache misses in the current session branch, joins each
 * with its trace record, and asks the agent to explain causes and fixes.
 * Cross-session report: scripts/cache-audit.py
 */
import { appendFileSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const LOG = join(homedir(), ".pi/agent/cache-trace.jsonl");
const log = (rec: Record<string, unknown>) => {
	try {
		appendFileSync(LOG, JSON.stringify({ ts: new Date().toISOString(), ...rec }) + "\n");
	} catch {}
};

// ~60 chars either side of the first differing character.
const around = (s: string, i: number) => s.slice(Math.max(0, i - 60), i + 60);

type TraceReq = { ts: string; session: string; kind: string; firstDiff: number | null; role?: string; before?: string; after?: string; count?: number; prevCount?: number };
type Usage = { input?: number; cacheRead?: number; cacheWrite?: number };

function traceRequests(session: string): TraceReq[] {
	let text = "";
	try {
		text = readFileSync(LOG, "utf8");
	} catch {
		return [];
	}
	const out: TraceReq[] = [];
	for (const line of text.split("\n")) {
		try {
			const r = JSON.parse(line) as TraceReq;
			if (r.kind === "request" && r.session === session) out.push(r);
		} catch {}
	}
	return out;
}

/** One line per cache miss in the branch, with events and trace diff before it. */
function findMisses(branch: any[], reqs: TraceReq[]): string[] {
	const lines: string[] = [];
	let prev: { ts: string; read: number; write: number; model?: string } | undefined;
	let events: string[] = [];
	for (const e of branch) {
		const m = e.type === "message" ? e.message : undefined;
		const u: Usage | undefined = m?.role === "assistant" ? m.usage : undefined;
		if (!u) {
			events.push(
				e.type === "custom" ? `custom:${e.customType}`
				: e.type === "custom_message" ? `custom_message:${e.customType}`
				: e.type === "message" ? `${m.role}${m.toolName ? `:${m.toolName}` : ""}`
				: e.type,
			);
			continue;
		}
		if (!u.cacheRead && !u.cacheWrite) continue;
		const cur = { ts: e.timestamp as string, read: u.cacheRead ?? 0, write: u.cacheWrite ?? 0, model: m.model };
		if (prev) {
			const expect = prev.read + prev.write;
			const lost = expect - cur.read;
			if (lost > 2000 && cur.read < expect * 0.9) {
				const gap = Math.round((Date.parse(cur.ts) - Date.parse(prev.ts)) / 1000);
				const req = reqs.filter((r) => r.ts > prev!.ts && r.ts <= cur.ts).at(-1);
				const trace = !req
					? "trace: none (request ran before cache-trace loaded)"
					: req.firstDiff === null
						? "trace: transcript unchanged (TTL expiry or provider-side change)"
						: `trace: first changed msg #${req.firstDiff} role=${req.role} (msgs ${req.prevCount}->${req.count})\n    before: ${JSON.stringify(req.before)}\n    after:  ${JSON.stringify(req.after)}`;
				lines.push(
					`- ${cur.ts} lost ${lost} tok (cacheRead ${cur.read}, cacheWrite ${cur.write}, expected ~${expect}), gap ${gap}s, model ${prev.model}->${cur.model}\n` +
						`  entries since last reply: ${[...new Set(events)].join(", ") || "none"}\n  ${trace}`,
				);
			}
		}
		prev = cur;
		events = [];
	}
	return lines;
}

export default function (pi: ExtensionAPI) {
	const prev = new Map<string, string[]>(); // session id -> serialized messages

	pi.on("context_with_system", (event, ctx) => {
		const session = ctx.sessionManager.getSessionId();
		const cur = event.messages.map((m) => JSON.stringify(m));
		const old = prev.get(session);
		prev.set(session, cur);
		if (!old) return log({ kind: "request", session, count: cur.length, firstDiff: null });

		let i = 0;
		while (i < old.length && i < cur.length && old[i] === cur[i]) i++;
		if (i === old.length) return log({ kind: "request", session, count: cur.length, firstDiff: null });

		const a = old[i] ?? "";
		const b = cur[i] ?? "";
		let c = 0;
		while (c < a.length && c < b.length && a[c] === b[c]) c++;
		log({
			kind: "request",
			session,
			count: cur.length,
			prevCount: old.length,
			firstDiff: i,
			role: (event.messages[i] as { role?: string } | undefined)?.role ?? "(removed)",
			before: around(a, c),
			after: around(b, c),
		});
	});

	pi.on("message_end", (event, ctx) => {
		const m = event.message as { role?: string; model?: string; usage?: Record<string, number> };
		if (m.role !== "assistant" || !m.usage) return;
		log({
			kind: "usage",
			session: ctx.sessionManager.getSessionId(),
			model: m.model,
			input: m.usage.input,
			cacheRead: m.usage.cacheRead,
			cacheWrite: m.usage.cacheWrite,
		});
	});

	pi.registerCommand("cache-audit", {
		description: "Audit this session's prompt-cache misses in a new tmux pane (separate Pi session)",
		handler: async (_args, ctx) => {
			if (!process.env.TMUX) return ctx.ui.notify("/cache-audit needs tmux: it opens the audit in a new pane.", "error");
			const sm = ctx.sessionManager;
			const file = sm.getSessionFile();
			const misses = findMisses(sm.getBranch(), traceRequests(sm.getSessionId()));
			if (misses.length === 0) return ctx.ui.notify("No cache misses in this session.", "info");
			const prompt = [
				`Cache-miss audit of another Pi session (${misses.length} misses), not this one.`,
				`A miss = cacheRead fell >2000 tokens and >10% below the previous reply's cacheRead+cacheWrite.`,
				`Audited session log: ${file ?? "(in memory, not on disk)"}. Trace log: ${LOG} (written by ~/.pi/agent/extensions/cache-trace.ts).`,
				"",
				...misses,
				"",
				"For each miss, determine the root cause: what changed in the request prefix, and which extension, tool, setting or Pi feature changed it. Read the session log entries around each timestamp and the source of the extension involved where needed. Treat compaction, idle gaps past the TTL and model switches as expected; focus on the avoidable ones.",
				"Report: a table of misses ranked by tokens lost with cause, then concrete fixes per cause (config, extension change, or habit). Do not edit any files.",
			].join("\n");
			// New pane, new session: the audit adds nothing to the audited session.
			const r = await pi.exec("tmux", ["split-window", "-h", "-c", ctx.cwd, "-e", `PATH=${process.env.PATH ?? ""}`, "--", "pi", "--name", "cache-audit", prompt]);
			if (r.code !== 0) return ctx.ui.notify(`tmux split-window failed: ${r.stderr.trim()}`, "error");
			ctx.ui.notify(`Cache audit (${misses.length} misses) started in a new tmux pane.`, "info");
		},
	});
}
