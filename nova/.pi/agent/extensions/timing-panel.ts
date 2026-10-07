/**
 * Right-side pane: where wall-clock time went — model wait, thinking, reply text, tool-arg writing,
 * tool execution (per tool, edit+write split out), blocking UI prompts, idle — for the current/last
 * agent run and the whole session. Background tasks (bg_run) run concurrently, so they're listed
 * separately (from their completion notifications), not in the wall-clock split.
 * Same layout swap as usage-panel.ts/diff-panel.ts; shares the ORIGINAL symbol → one side pane at a time.
 * Needs "tuiMode": "fullscreen".
 *   Ctrl+Alt+T / /timing        show / hide
 *   Alt+T / /timing focus       focus pane (opens it if hidden); Alt+T again → back to editor
 *   /timing close               hide
 *   focused: ↑↓ PgUp/PgDn Home/End scroll, Esc/Alt+T back to editor, q hide
 * Session totals are saved as a "timing-panel" custom entry at each agent_settled (never sent to the
 * model) and restored on session_start. Only sessions run with this extension loaded are measured.
 */
import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { HStack, matchesKey, ScrollView, truncateToWidth, VStack } from "@earendil-works/pi-tui";

const ORIGINAL = Symbol.for("diff-panel.originalRoot");
const PREV_FOCUS = Symbol.for("diff-panel.prevFocus");
const ENTRY = "timing-panel";
const EDIT_TOOLS = new Set(["edit", "write"]);

const PHASES = {
	wait: "Model wait",
	thinking: "Thinking",
	text: "Writing reply",
	toolArgs: "Writing tool args",
	tools: "Tool execution",
	prompt: "Waiting on you",
	idle: "Idle",
} as const;
type Phase = keyof typeof PHASES;
type Stats = {
	ph: Record<string, number>;
	tools: Record<string, { n: number; ms: number }>;
	bg: { n: number; ms: number };
	runs: number;
	start: number;
};
const fresh = (): Stats => ({ ph: {}, tools: {}, bg: { n: 0, ms: 0 }, runs: 0, start: Date.now() });

// ---------- measurement ----------

let sess = fresh();
let run: Stats | undefined; // current agent run, kept after it ends for "LAST RUN"
let runLive = false;
let phase: Phase = "idle";
let since = Date.now();
let beforePrompt: Phase = "idle";
const toolStart = new Map<string, number>(); // top-level toolCallId → start ms
const bgSeen = new Set<string>();

const live = () => [sess, runLive ? run : undefined].filter(Boolean) as Stats[];

function switchTo(p: Phase) {
	const now = Date.now();
	for (const s of live()) s.ph[phase] = (s.ph[phase] ?? 0) + now - since;
	phase = p;
	since = now;
}

function addTool(name: string, ms: number) {
	for (const s of live()) {
		const t = (s.tools[name] ??= { n: 0, ms: 0 });
		t.n++;
		t.ms += ms;
	}
}

// ---------- rendering ----------

let tui: any; // pi's TUI; layoutRoot/setLayoutRoot are fullscreen-renderer internals
let theme: Theme;
let root: any;
let pane: any;
let body: ScrollView;
let timer: ReturnType<typeof setInterval> | null = null;

const dur = (ms: number) => {
	if (ms < 1000) return `${Math.round(ms)}ms`;
	const s = ms / 1000;
	if (s < 60) return `${s.toFixed(1)}s`;
	const m = Math.floor(s / 60);
	if (m < 60) return `${m}m${String(Math.floor(s % 60)).padStart(2, "0")}s`;
	return `${Math.floor(m / 60)}h${String(m % 60).padStart(2, "0")}m`;
};
const IST = new Intl.DateTimeFormat("en-GB", { timeZone: "Asia/Kolkata", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit", hour12: false });

function section(out: string[], title: string, s: Stats, open: boolean, w: number) {
	const th = theme;
	const ph = { ...s.ph };
	if (open) ph[phase] = (ph[phase] ?? 0) + Date.now() - since;
	const wall = Object.values(ph).reduce((a, b) => a + b, 0) || 1;
	const kv = (k: string, v: string) => out.push(`  ${th.fg("muted", k.padEnd(18))}${v}`);
	const bw = Math.max(6, w - 32);
	const bar = (ms: number) => {
		const f = Math.round((ms / wall) * bw);
		return th.fg("accent", "█".repeat(f)) + th.fg("dim", "░".repeat(bw - f));
	};

	out.push("", " " + th.bold(th.fg("accent", title)));
	kv("Wall time", dur(wall));
	const model = ["wait", "thinking", "text", "toolArgs"].reduce((a, k) => a + (ph[k] ?? 0), 0);
	kv("Model total", `${dur(model)}  ${th.fg("dim", `${Math.round((model / wall) * 100)}%`)}`);
	for (const k of Object.keys(PHASES) as Phase[]) {
		const ms = ph[k] ?? 0;
		if (!ms) continue;
		const mark = open && k === phase ? th.fg("success", "●") : " ";
		out.push(`${mark} ${th.fg("muted", PHASES[k].padEnd(18))}${dur(ms).padStart(7)} ${th.fg("dim", `${String(Math.round((ms / wall) * 100)).padStart(3)}%`)}`);
		out.push(`    ${bar(ms)}`);
	}

	const tools = Object.entries(s.tools).sort((a, b) => b[1].ms - a[1].ms);
	if (tools.length) {
		out.push(th.fg("dim", "  tools (summed; parallel calls overlap)"));
		const edit = tools.filter(([n]) => EDIT_TOOLS.has(n.replace(/^mcp__pi__/, ""))).reduce((a, [, t]) => a + t.ms, 0);
		if (edit) kv("Editing", th.fg("text", dur(edit)) + th.fg("dim", "  edit+write"));
		for (const [name, t] of tools) kv(name.replace(/^mcp__pi__/, ""), `${dur(t.ms).padStart(7)} ${th.fg("dim", `×${t.n}`)}`);
	}
	if (s.bg.n) kv("Background tasks", `${dur(s.bg.ms)} ${th.fg("dim", `×${s.bg.n} (concurrent)`)}`);
}

function bodyLines(w: number): string[] {
	const out: string[] = [];
	if (run) section(out, runLive ? "CURRENT RUN" : "LAST RUN", run, runLive, w);
	else out.push("", theme.fg("dim", "  no agent run yet"));
	section(out, `SESSION · ${sess.runs} runs · since ${IST.format(new Date(sess.start))} IST`, sess, true, w);
	return out;
}

// ---------- layout (mirrors usage-panel.ts) ----------

class Lines {
	constructor(private fn: (w: number) => string[]) {}
	render(w: number) {
		return this.fn(w).map((l) => truncateToWidth(l, w, "…"));
	}
	invalidate() {}
}

function capture(ctx: ExtensionContext): boolean {
	if (ctx.mode !== "tui") return false;
	ctx.ui.setWidget("timing-panel-probe", (t, th) => {
		tui = t;
		theme = th;
		return { render: () => [], invalidate() {} };
	});
	ctx.ui.setWidget("timing-panel-probe", undefined);
	return typeof tui?.setLayoutRoot === "function" && !!tui.layoutRoot;
}

const shown = () => !!root && tui?.layoutRoot === root;
const focused = () => shown() && tui.getFocusedComponent() === pane;

function onKey(data: string) {
	if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c") || matchesKey(data, "alt+t")) return unfocus();
	if (matchesKey(data, "ctrl+alt+t") || data === "q") return hide();
	const page = Math.max(1, body.viewportHeight - 1);
	if (matchesKey(data, "up")) body.scrollBy(-1);
	else if (matchesKey(data, "down")) body.scrollBy(1);
	else if (matchesKey(data, "pageUp")) body.scrollBy(-page);
	else if (matchesKey(data, "pageDown")) body.scrollBy(page);
	else if (matchesKey(data, "home")) body.scrollToStart();
	else if (matchesKey(data, "end")) body.scrollToEnd();
	tui.requestRender();
}

function show(ctx: ExtensionContext) {
	if (!capture(ctx)) {
		ctx.ui.notify('Timing panel needs "tuiMode": "fullscreen" in settings.json', "warning");
		return;
	}
	if (shown()) return tui.requestRender();
	const f = tui.getFocusedComponent();
	if (f?.[PREV_FOCUS]) tui.setFocus(f[PREV_FOCUS]);
	const original = tui.layoutRoot[ORIGINAL] ?? tui.layoutRoot; // VStack [transcript, input dock]
	const [main, dock] = original.entries;

	body = new ScrollView(new Lines(bodyLines), { scrollbar: "auto" });
	const content = new VStack([
		{ component: new Lines(() => [` ${theme.bold(theme.fg("accent", "TIME BREAKDOWN"))}`]) },
		{ component: body, basis: 0, grow: 1, shrink: 1, minSize: 1 },
		{
			component: new Lines((w) => [
				theme.fg("borderMuted", "─".repeat(w)),
				theme.fg("dim", focused() ? " ↑↓ scroll  Esc back  q hide" : " Alt+T focus  Ctrl+Alt+T hide"),
			]),
		},
	]);
	const divider = new Lines(() => Array(tui.terminal.rows).fill(theme.fg(focused() ? "accent" : "dim", "│")));
	pane = new HStack([
		{ component: divider, basis: 1 },
		{ component: content, basis: 0, grow: 1 },
	]);
	pane.handleInput = onKey;

	const split = new HStack([main, { component: pane, basis: 0, visible: (v: { width: number }) => v.width >= 100 }]);
	Object.defineProperty(split.entries[1], "basis", { get: () => Math.max(40, Math.floor(tui.terminal.columns / 4)) });
	root = new VStack([{ ...main, component: split }, dock]);
	root[ORIGINAL] = original;
	tui.setLayoutRoot(root);
	// live clock only while visible; no per-event rendering
	timer ??= setInterval(() => shown() && tui.requestRender(), 1000);
}

function focus() {
	pane[PREV_FOCUS] = tui.getFocusedComponent();
	tui.setFocus(pane);
	tui.requestRender();
}

function unfocus() {
	if (tui.getFocusedComponent() === pane) tui.setFocus(pane[PREV_FOCUS] ?? null);
	tui.requestRender();
}

function hide() {
	if (timer) clearInterval(timer);
	timer = null;
	if (!shown()) return;
	unfocus();
	tui.setLayoutRoot(root[ORIGINAL]);
	root = undefined;
}

const toggle = (ctx: ExtensionContext) => (shown() ? hide() : show(ctx));
function focusToggle(ctx: ExtensionContext) {
	if (focused()) return unfocus();
	show(ctx);
	if (shown()) focus();
}

// ---------- wiring ----------

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_e, ctx) => {
		const saved = (ctx.sessionManager.getEntries() as any[]).findLast((e) => e.type === "custom" && e.customType === ENTRY);
		sess = saved?.data?.sess ?? fresh();
		run = undefined;
		runLive = false;
		phase = "idle";
		since = Date.now();
		toolStart.clear();
		root = undefined;
		if (!capture(ctx)) return;
		// undo a pane left behind by a previous load (e.g. /reload)
		const f = tui.getFocusedComponent();
		if (f?.[PREV_FOCUS]) tui.setFocus(f[PREV_FOCUS]);
		if (tui.layoutRoot[ORIGINAL]) tui.setLayoutRoot(tui.layoutRoot[ORIGINAL]);
	});

	pi.on("agent_start", () => {
		switchTo("wait"); // closes idle on the session only
		run = fresh();
		run.runs = 1;
		runLive = true;
		sess.runs++;
	});

	pi.on("message_update", (e) => {
		if (toolStart.size) return;
		const t = e.assistantMessageEvent.type;
		if (t === "thinking_start") switchTo("thinking");
		else if (t === "text_start") switchTo("text");
		else if (t === "toolcall_start") switchTo("toolArgs");
	});

	pi.on("message_end", (e) => {
		const m: any = e.message;
		if (m.role === "assistant" && !toolStart.size && phase !== "prompt") switchTo("wait");
		// bg_run completion → concurrent background time (startTime/endTime are Date.now() ms)
		const d = m.role === "custom" && m.customType === "background-task-notification" ? m.details : undefined;
		if (d?.id && d.startTime && d.endTime && !bgSeen.has(d.id)) {
			bgSeen.add(d.id);
			for (const s of live()) {
				s.bg.n++;
				s.bg.ms += d.endTime - d.startTime;
			}
		}
	});

	pi.on("tool_execution_start", (e) => {
		if (e.parentToolCallId) return; // nested (codemode) calls are inside the parent's time
		toolStart.set(e.toolCallId, Date.now());
		if (phase !== "tools" && phase !== "prompt") switchTo("tools");
	});

	pi.on("tool_execution_end", (e) => {
		const t0 = toolStart.get(e.toolCallId);
		if (t0 === undefined) return;
		toolStart.delete(e.toolCallId);
		addTool(e.toolName, Date.now() - t0);
		if (!toolStart.size && phase === "tools") switchTo("wait");
	});

	pi.on("ui_prompt_start", () => {
		if (phase === "prompt") return;
		beforePrompt = phase;
		switchTo("prompt");
	});
	pi.on("ui_prompt_end", () => {
		if (phase === "prompt") switchTo(beforePrompt);
	});

	pi.on("agent_settled", () => {
		switchTo("idle");
		runLive = false;
		toolStart.clear();
		pi.appendEntry(ENTRY, { sess });
	});

	pi.on("session_shutdown", () => {
		if (timer) clearInterval(timer);
		timer = null;
	});

	pi.registerShortcut("ctrl+alt+t", { description: "Timing panel: show/hide", handler: (ctx) => toggle(ctx) });
	pi.registerShortcut("alt+t", { description: "Timing panel: focus / back to editor", handler: (ctx) => focusToggle(ctx) });
	pi.registerCommand("timing", {
		description: "Time breakdown side pane: toggle | focus | close",
		handler: async (args, ctx) => {
			const a = args.trim();
			if (a === "close") hide();
			else if (a === "focus") focusToggle(ctx);
			else toggle(ctx);
		},
	});
}
