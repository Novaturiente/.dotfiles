/**
 * Batched todo list for the main pi session. One `todo` call can add, start, finish and drop
 * several items, so progress updates ride along with real tool calls instead of costing turns.
 * Shows as the "Todos" section of the side panel's Agent tab (../panel); outside tmux a compact
 * widget sits above the editor instead. State is a snapshot appended to the session on every
 * change and replayed on start/tree/compact (also reads old rpiv-todo snapshots).
 */
import { Type } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import * as panel from "../panel/lib.mjs";

type Status = "pending" | "active" | "done" | "dropped";
type Task = { id: number; subject: string; status: Status; note?: string; startedAt?: number; doneAt?: number };
type State = { tasks: Task[]; next: number };

const ENTRY = "todo-state";
const SOURCE = "todo";
const OPEN = new Set<Status>(["pending", "active"]);
const ICON: Record<Status, string> = { pending: "○", active: "◐", done: "✓", dropped: "✗" };
const PANEL_STATUS: Record<Status, string> = { pending: "queued", active: "running", done: "done", dropped: "stopped" };
// Nerd Font checkbox glyphs + ANSI colour for the panel rows.
const PANEL_ICON: Record<Status, [string, number]> = { pending: ["\uf096", 90], active: ["\uf192", 33], done: ["\uf14a", 32], dropped: ["\uf05e", 90] };
const bar = (done: number, total: number, w = 10) => {
	const n = total ? Math.round((done / total) * w) : 0;
	return `\x1b[32m${"▰".repeat(n)}\x1b[90m${"▱".repeat(w - n)}\x1b[0m`;
};
const OLD_STATUS: Record<string, Status> = { pending: "pending", in_progress: "active", completed: "done", deleted: "dropped" };

const line = (t: Task) => `${ICON[t.status]} #${t.id} ${t.subject}${t.status === "active" && t.note ? ` (${t.note})` : ""}`;

/** Last snapshot on the branch: ours, or an rpiv-todo one from before the switch. */
function replay(ctx: ExtensionContext): State {
	let s: State = { tasks: [], next: 1 };
	for (const e of ctx.sessionManager.getBranch() as any[]) {
		if (e.type !== "custom") continue;
		if (e.customType === ENTRY && Array.isArray(e.data?.tasks)) s = structuredClone(e.data);
		else if (e.customType === "rpiv-todo-state" && Array.isArray(e.data?.tasks))
			s = {
				tasks: e.data.tasks.map((t: any) => ({
					id: t.id,
					subject: t.subject,
					status: OLD_STATUS[t.status] ?? "pending",
					note: t.activeForm,
				})),
				next: e.data.nextId,
			};
	}
	return s;
}

export default function (pi: ExtensionAPI) {
	if (process.env.PI_SWARM_ID) return; // subagents report back instead of planning in a list
	let state: State = { tasks: [], next: 1 };
	let ui: ExtensionContext["ui"] | undefined;
	const open = () => state.tasks.filter((t) => OPEN.has(t.status));
	const progress = () =>
		`${state.tasks.filter((t) => t.status === "done").length}/${state.tasks.filter((t) => t.status !== "dropped").length} done`;

	let published = false;
	function show() {
		if (panel.panelDir()) {
			panel.clearSource(SOURCE);
			if (!open().length) {
				// Plan finished: take the pane down unless subagents still work in it.
				if (published && !panel.busy(SOURCE)) panel.hidePane();
				published = false;
				return;
			}
			published = true;
			const live = state.tasks.filter((t) => t.status !== "dropped");
			const done = live.filter((t) => t.status === "done").length;
			panel.setSource(SOURCE, { title: `\uf0ae Todos ${done}/${live.length} ${bar(done, live.length)}`, order: 5 });
			for (const t of state.tasks)
				panel.publish(SOURCE, {
					id: `t${t.id}`,
					label: t.subject,
					tag: `#${t.id}`,
					status: PANEL_STATUS[t.status],
					icon: PANEL_ICON[t.status],
					dim: t.status === "done" || t.status === "dropped",
					// Time spent from start to done; ticks while active.
					time: t.startedAt ? (t.status === "active" ? { since: t.startedAt } : t.doneAt ? { ms: t.doneAt - t.startedAt } : undefined) : undefined,
					order: t.id,
					detail: t.status === "active" && t.note ? `\x1b[33m\uf0da\x1b[0m ${t.note}` : undefined,
				});
			panel.ensurePane({ title: "Agent" });
		} else if (ui) {
			// Compact fallback outside tmux: heading, what's active, what's next.
			const active = state.tasks.filter((t) => t.status === "active");
			const next = state.tasks.find((t) => t.status === "pending");
			ui.setWidget(
				"todos",
				open().length ? [`Todos ${progress()}`, ...active.map(line), ...(next ? [`next ${line(next)}`] : [])] : undefined,
			);
		}
	}

	const load = (_e: unknown, ctx: ExtensionContext) => {
		state = replay(ctx);
		if (ctx.hasUI) ui = ctx.ui;
		show();
	};
	pi.on("session_start", load);
	pi.on("session_tree", load);
	pi.on("session_compact", load);
	pi.on("session_shutdown", () => {
		if (panel.panelDir()) panel.clearSource(SOURCE);
	});

	const ids = Type.Optional(Type.Array(Type.Number()));
	pi.registerTool({
		name: "todo",
		label: "Todo",
		description:
			"Plan and track multi-step work. One call can do several things: set (replace the whole plan), add (append items), done/drop (finish or cancel ids), start (mark one id active, with an optional note). A call with no fields lists the plan.",
		promptSnippet: "todo: batched task list shown in the side panel",
		promptGuidelines: [
			"Use `todo` for work with 3+ steps or when the user gives a list of tasks; skip it for trivial or conversational requests.",
			"Batch: one todo call can finish the last item and start the next (`done:[2], start:3, note:'writing tests'`). Put that call in the same message as the first real tool call of the next step; never spend a turn only on todo.",
			"Don't mark an item done while its tests fail or the work is partial; add an item for the blocker instead.",
		],
		parameters: Type.Object({
			set: Type.Optional(Type.Array(Type.String(), { description: "Replace the plan with these items (short imperative subjects)" })),
			add: Type.Optional(Type.Array(Type.String(), { description: "Append items" })),
			done: ids,
			drop: ids,
			start: Type.Optional(Type.Number({ description: "Id to mark active" })),
			note: Type.Optional(Type.String({ description: "What the started item is doing now, e.g. 'writing tests'" })),
		}),
		async execute(_id, p) {
			const saved = state;
			const msgs: string[] = [];
			const before = JSON.stringify(state);
			state = structuredClone(state); // a bad id below rolls the whole call back
			try {
				const find = (id: number) => {
					const t = state.tasks.find((x) => x.id === id);
					if (!t) throw new Error(`no todo #${id}`);
					return t;
				};
				// A finished plan makes way for the next one.
				if (p.set || (p.add?.length && !open().length)) state = { tasks: [], next: p.set ? 1 : state.next };
				for (const subject of [...(p.set ?? []), ...(p.add ?? [])]) state.tasks.push({ id: state.next++, subject, status: "pending" });
				for (const id of p.done ?? []) Object.assign(find(id), { status: "done", note: undefined, doneAt: Date.now() });
				for (const id of p.drop ?? []) Object.assign(find(id), { status: "dropped", note: undefined });
				if (p.start !== undefined) Object.assign(find(p.start), { status: "active", note: p.note, startedAt: Date.now() });
				if (p.set || p.add?.length)
					msgs.push(
						`added ${state.tasks
							.slice(-(p.set ?? []).length - (p.add ?? []).length)
							.map((t) => `#${t.id} ${t.subject}`)
							.join(", ")}`,
					);
			} catch (e) {
				state = saved;
				throw new Error(`${(e as Error).message}; nothing changed. Plan:\n${state.tasks.map(line).join("\n") || "(empty)"}`);
			}
			const listOnly = !p.set && !p.add && !p.done && !p.drop && p.start === undefined;
			if (JSON.stringify(state) !== before) {
				pi.appendEntry(ENTRY, structuredClone(state));
				show();
			}
			const next = state.tasks.find((t) => t.status === "pending");
			const text =
				listOnly || p.set
					? `${progress()}\n${state.tasks.map(line).join("\n") || "(empty)"}`
					: [...msgs, progress() + (open().length ? "" : " — plan finished"), next ? `next: #${next.id} ${next.subject}` : ""]
							.filter(Boolean)
							.join(" · ");
			return { content: [{ type: "text", text }], details: structuredClone(state) };
		},
	});

	pi.registerCommand("todos", {
		description: "Print the todo list",
		handler: async (_a, ctx) =>
			ctx.ui.notify(state.tasks.length ? `${progress()}\n${state.tasks.map(line).join("\n")}` : "No todos", "info"),
	});
}
