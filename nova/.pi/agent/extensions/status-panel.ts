/**
 * Moves the subagent and todo widgets out of the dock above the input into a right-side pane
 * (25%, min 40 cols, full window height; input and footer narrow to the left column). Pane shows
 * while any of them renders something, hides when all are blank or gone; several split the pane
 * into equal top-aligned sections in KEYS order (overflow clipped).
 * Display only, no focus or keys.
 * Terminal under 100 cols, regular tuiMode, or another side pane (timing-panel) showing →
 * the widgets stay in the dock as before.
 * Patches InteractiveMode.renderWidgets: pi has no public hook that sees widget keys.
 */
import { InteractiveMode, type ExtensionAPI, type ExtensionUIContext } from "@earendil-works/pi-coding-agent";
import { HStack, truncateToWidth, VStack, type Component } from "@earendil-works/pi-tui";

const ORDER = ["subagent-async", "subagent-fleet-status", "rpiv-todos"]; // top to bottom
const KEYS = new Set(ORDER);
const ORIGINAL = Symbol.for("diff-panel.originalRoot"); // shared with timing-panel.ts
const MINE = Symbol.for("status-panel.root");
const ORIG_RENDER = Symbol.for("status-panel.origRenderWidgets"); // survives /reload
const MIN_COLS = 100;

let tui: any; // pi's TUI; layoutRoot/setLayoutRoot are fullscreen-renderer internals
let ui: ExtensionUIContext | undefined;
let side: Component[] = [];

const lines = (fn: (w: number) => string[]): Component => ({
	render: (w) => fn(w).map((l) => truncateToWidth(l, w, "…")),
	invalidate() {},
});
const dim = (s: string) => (ui ? ui.theme.fg("dim", s) : s);
const inPane = () => !!tui?.layoutRoot?.[MINE] && tui.terminal.columns >= MIN_COLS;
const paneWidth = () => Math.max(40, Math.floor(tui.terminal.columns / 4));
const blank = (l: string) => !l.replace(/\x1b\[[0-9;:]*m/g, "").trim();

// Widgets that render something right now. Widgets update in place (a finished subagent or
// cleared todo list can go blank without unsetting), so this is checked per frame.
let liveCache: Component[] | undefined;
// rpiv-todo heading "Todos (n/n)": every item done. rpiv-todo keeps such a list up until the next
// turn; drop it once nothing else is shown, so the pane closes right away.
// shortcut: matches the English heading text, breaks if rpiv-todo's locale or wording changes.
const allDone = (l: string) => {
	const m = l.replace(/\x1b\[[0-9;:]*m/g, "").match(/Todos \((\d+)\/(\d+)\)/);
	return !!m && m[1] === m[2];
};
const live = () => {
	if (!liveCache) {
		const shown = side.map((c) => ({ c, l: c.render(paneWidth() - 1) })).filter((s) => !s.l.every(blank));
		const busy = shown.filter((s) => !allDone(s.l[0] ?? ""));
		liveCache = (busy.length ? shown : busy).map((s) => s.c);
		queueMicrotask(() => (liveCache = undefined));
	}
	return liveCache;
};

// Sits in the dock; shows the widgets there whenever the pane can't. Also reclaims the layout
// after timing-panel hides (it restores the bare root without telling us).
const dockProxy = lines((w) => {
	if (inPane()) return [];
	if (side.length && tui?.layoutRoot && !tui.layoutRoot[ORIGINAL]) queueMicrotask(sync);
	return side.flatMap((c) => c.render(w));
});

// One equal-height section; every live section after the first starts with a rule.
const section = (c: Component): Component => ({
	render: (w) => (live().indexOf(c) > 0 ? [dim("─".repeat(w)), ...c.render(w)] : c.render(w)),
	invalidate: () => c.invalidate(),
});

function sync() {
	const lr = tui?.layoutRoot;
	if (!lr || typeof tui.setLayoutRoot !== "function") return; // regular tuiMode
	if (lr[ORIGINAL] && !lr[MINE]) return; // another side pane owns the layout
	const original = lr[ORIGINAL] ?? lr; // VStack [transcript, input dock]
	if (!side.length) {
		if (lr[MINE]) tui.setLayoutRoot(original);
		return;
	}
	const content: any = new VStack(
		side.map((c) => ({ component: section(c), basis: 0, grow: 1, shrink: 1, minSize: 1, visible: () => live().includes(c) })),
	);
	// pi-tui's grow hands out space greedily (first entry takes half of what's left), so start
	// every section at an equal share of the pane; only rounding rows are left to grow.
	const share = () => Math.floor(tui.terminal.rows / Math.max(1, live().length));
	for (const e of content.entries) Object.defineProperty(e, "basis", { get: share });
	const divider = lines(() => Array(tui.terminal.rows).fill(dim("│")));
	const pane = new HStack([
		{ component: divider, basis: 1 },
		{ component: content, basis: 0, grow: 1 },
	]);
	const root: any = new HStack([
		{ component: original, basis: 0, grow: 1, shrink: 1, minSize: 1 },
		{ component: pane, basis: 0, visible: (v: { width: number }) => v.width >= MIN_COLS && live().length > 0 },
	]);
	// addChild copies basis once; make it follow terminal width
	Object.defineProperty(root.entries[1], "basis", { get: paneWidth });
	root[ORIGINAL] = original;
	root[MINE] = true;
	tui.setLayoutRoot(root);
}

const P = InteractiveMode.prototype as any;
P[ORIG_RENDER] ??= P.renderWidgets;
const origRender = P[ORIG_RENDER];
// renderWidgets, not renderWidgetContainer: statusline-tweaks.ts wraps that one and caches the
// original it first saw, which drops this patch after a /reload.
P.renderWidgets = function (this: any) {
	const above: Map<string, Component> = this.extensionWidgetsAbove;
	if (!above || !this.widgetContainerAbove) return origRender.call(this);
	tui = this.ui;
	side = [...above]
		.filter(([k]) => KEYS.has(k))
		.sort(([a], [b]) => ORDER.indexOf(a) - ORDER.indexOf(b))
		.map(([, c]) => c);
	this.extensionWidgetsAbove = new Map([...above].filter(([k]) => !KEYS.has(k)));
	try {
		origRender.call(this);
	} finally {
		this.extensionWidgetsAbove = above; // setExtensionWidget keeps writing to the real map
	}
	if (side.length) this.widgetContainerAbove.addChild(dockProxy);
	sync();
};

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_e, ctx) => {
		ui = ctx.ui;
	});
}
