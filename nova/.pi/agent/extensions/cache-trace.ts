/**
 * Prompt-cache miss tracer. Before each model request, compares the full
 * transcript with the previous request's and logs the first message that
 * changed (a change there invalidates the cached prefix from that point).
 * Also logs per-response cache usage. Read with scripts/cache-audit.py.
 * Log: ~/.pi/agent/cache-trace.jsonl
 */
import { appendFileSync } from "node:fs";
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
}
