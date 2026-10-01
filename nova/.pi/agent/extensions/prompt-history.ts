/**
 * Up-arrow prompt history scoped to the current session.
 * Pi only seeds editor history when a session is first rendered, so a swapped-in
 * editor (pi-ui BoxedEditor, powerline) or a compacted session would lose it.
 * On the first up-press per editor per session, history is rebuilt from that
 * session's own user messages (all entries, so compaction doesn't drop them).
 */
import { Editor } from "@earendil-works/pi-tui";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MAX = 200; // entries shown in the up-arrow list
const STATE = Symbol.for("nova.prompt-history.state");
const g = globalThis as any;
g[STATE] ??= { sm: undefined as any };

function sessionPrompts(sm: any): string[] {
	const out: string[] = [];
	for (const e of sm?.getEntries?.() ?? []) {
		if (e.type !== "message" || e.message?.role !== "user") continue;
		const c = e.message.content;
		const text = (typeof c === "string" ? c : (c ?? []).filter((b: any) => b.type === "text").map((b: any) => b.text).join("\n")).trim();
		if (text) out.push(text);
	}
	return [...new Set(out.reverse())].slice(0, MAX); // newest first
}

// Patch the shared Editor prototype once per process; wrap the true original so /reload never stacks patches.
const ORIGINAL = Symbol.for("nova.prompt-history.original");
const proto = Editor.prototype as any;
proto[ORIGINAL] ??= proto.navigateHistory;
const seededFor = new WeakMap<object, string>();
proto.navigateHistory = function (this: any, direction: number) {
	const sm = g[STATE].sm;
	const id = sm?.getSessionId?.();
	if (id && seededFor.get(this) !== id && Array.isArray(this.history)) {
		seededFor.set(this, id);
		this.history.splice(0, this.history.length, ...sessionPrompts(sm));
	}
	return proto[ORIGINAL].call(this, direction);
};

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_e, ctx) => {
		g[STATE].sm = ctx.sessionManager;
	});
}
