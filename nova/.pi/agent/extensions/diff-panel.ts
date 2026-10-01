/**
 * Right-side pane (25%, min 40 cols) listing files edited this session + unified diff (original → now).
 * A real pane, not an overlay: transcript reflows to the left, pane ends just above the input dock.
 * Needs "tuiMode": "fullscreen". Never opens by itself; edits are tracked in the background.
 *   Ctrl+Alt+D / /diffpanel        show / hide
 *   Alt+D / /diffpanel focus       focus pane (opens it if hidden); Alt+D again → back to editor
 *   /diffpanel close               hide
 *   focused: ↑↓ PgUp/PgDn Home/End scroll, ←→/Tab switch file, Esc/Alt+D back to editor, q hide
 * Alt+D was the editor's delete-word-forward; keybindings.json moves that to Alt+Delete only.
 */
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { basename, dirname, relative, resolve } from "node:path";
import { renderDiff, type ExtensionAPI, type ExtensionContext, type Theme } from "@earendil-works/pi-coding-agent";
import { HStack, matchesKey, ScrollView, truncateToWidth, visibleWidth, VStack, wrapTextWithAnsi } from "@earendil-works/pi-tui";

// Symbol.for so a /reload can still find and undo the previous instance's layout
const ORIGINAL = Symbol.for("diff-panel.originalRoot");
const PREV_FOCUS = Symbol.for("diff-panel.prevFocus");

const originals = new Map<string, string | null>(); // abs path -> content before first edit (null = new file)
const diffs = new Map<string, string[]>(); // abs path -> current unified diff lines
let cwd = process.cwd();
let sel = 0;
let tui: any; // pi's TUI; layoutRoot/setLayoutRoot are fullscreen-renderer internals
let theme: Theme;
let root: any; // our layout root while shown
let pane: any; // focus target
let body: ScrollView;

function diffOf(abs: string): string[] {
	const rel = relative(cwd, abs);
	const target = existsSync(abs) ? abs : "/dev/null";
	try {
		execFileSync("diff", ["-u", "--label", `a/${rel}`, "--label", `b/${rel}`, "-", target], {
			input: originals.get(abs) ?? "",
			encoding: "utf8",
		});
		return []; // exit 0 = identical
	} catch (e: any) {
		return String(e.stdout ?? "").replace(/\n$/, "").replaceAll("\t", "  ").split("\n"); // exit 1 = differs
	}
}

/** Grab pi's TUI via a throwaway widget factory. True when the fullscreen layout can be swapped. */
function capture(ctx: ExtensionContext): boolean {
	if (ctx.mode !== "tui") return false;
	ctx.ui.setWidget("diff-panel-probe", (t, th) => {
		tui = t;
		theme = th;
		return { render: () => [], invalidate() {} };
	});
	ctx.ui.setWidget("diff-panel-probe", undefined);
	return typeof tui?.setLayoutRoot === "function" && !!tui.layoutRoot;
}

const shown = () => !!root && tui?.layoutRoot === root;
const focused = () => shown() && tui.getFocusedComponent() === pane;

class Lines {
	constructor(private fn: (w: number) => string[]) {}
	render(w: number) {
		return this.fn(w).map((l) => truncateToWidth(l, w, "…"));
	}
	invalidate() {}
}

/** Unified diff → rows [prefix, line number | null (hunk gap), content]; skips ---/+++ file headers. */
function hunks(d: string[]): [string, number | null, string][] {
	const rows: [string, number | null, string][] = [];
	let o = 0;
	let n = 0;
	let inHunk = false;
	for (const l of d) {
		const h = l.match(/^@@ -(\d+)(?:,\d+)? \+(\d+)/);
		if (h) {
			if (rows.length) rows.push([" ", null, ""]);
			[o, n, inHunk] = [+h[1], +h[2], true];
		} else if (!inHunk || l.startsWith("\\")) continue;
		else if (l[0] === "-") rows.push(["-", o++, l.slice(1)]);
		else if (l[0] === "+") rows.push(["+", n++, l.slice(1)]);
		else {
			rows.push([" ", n, l.slice(1)]);
			o++;
			n++;
		}
	}
	return rows;
}

const stats = (d: string[]) => {
	const r = hunks(d);
	return { add: r.filter((x) => x[0] === "+").length, del: r.filter((x) => x[0] === "-").length };
};

function header(w: number): string[] {
	const th = theme;
	const files = [...diffs.keys()];
	const all = files.map((f) => stats(diffs.get(f) ?? []));
	const tot = all.reduce((a, s) => ({ add: a.add + s.add, del: a.del + s.del }), { add: 0, del: 0 });
	const out = [
		` ${th.bold(th.fg("accent", "DIFF"))}  ${th.fg("muted", `${files.length} file${files.length === 1 ? "" : "s"}`)}  ${th.fg("success", `+${tot.add}`)} ${th.fg("error", `-${tot.del}`)}`,
		"",
	];
	const max = 6;
	const start = Math.max(0, Math.min(sel - 2, files.length - max));
	files.slice(start, start + max).forEach((f, j) => {
		const i = start + j;
		const { add, del } = all[i];
		const rel = relative(cwd, f);
		const dir = dirname(rel);
		const stat = `${th.fg("success", `+${add}`)} ${th.fg("error", `-${del}`)}`;
		const statW = visibleWidth(`+${add} -${del}`);
		const name = i === sel ? th.fg("accent", "▌ ") + th.bold(basename(rel)) : `  ${th.fg("text", basename(rel))}`;
		const left =
			name + (originals.get(f) === null ? th.fg("warning", " new") : "") + (dir !== "." ? th.fg("dim", `  ${dir}`) : "");
		out.push(`${truncateToWidth(left, Math.max(1, w - statW - 2), "…", true)} ${stat} `);
	});
	if (files.length > max) out.push(th.fg("dim", `  ${sel + 1} of ${files.length} files`));
	if (!files.length) out.push(th.fg("dim", "  no edits yet"));
	out.push(th.fg("borderMuted", "─".repeat(w)));
	return out;
}

// renderDiff = pi's own edit-tool renderer: line numbers, theme diff colors, word-level highlights
let cache: { d?: string[]; lines: string[]; gutter: number } = { lines: [], gutter: 0 };
function rendered(d: string[]) {
	if (cache.d !== d) {
		const rows = hunks(d);
		const nw = String(Math.max(0, ...rows.map((r) => r[1] ?? 0))).length;
		const text = rows
			.map(([p, num, c]) => (num === null ? `${" ".repeat(nw + 1)} ⋯` : `${p}${String(num).padStart(nw)} ${c}`))
			.join("\n");
		cache = { d, lines: rows.length ? renderDiff(text).split("\n") : [], gutter: nw + 2 };
	}
	return cache;
}

function diffBody(w: number): string[] {
	const d = diffs.get([...diffs.keys()][sel] ?? "") ?? [];
	if (diffs.size && !d.length) return [theme.fg("dim", "  no changes vs original")];
	const { lines, gutter } = rendered(d);
	// wrap long lines; continuation lines indent past the line-number gutter
	return lines.flatMap((l) =>
		wrapTextWithAnsi(l, Math.max(10, w - 2 - gutter)).map((x, i) => (i ? " " + " ".repeat(gutter) : " ") + x),
	);
}

function pick(i: number) {
	const n = diffs.size || 1;
	sel = (i + n) % n;
	body?.scrollToStart();
}

function onKey(data: string) {
	if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c") || matchesKey(data, "alt+d")) return unfocus();
	if (matchesKey(data, "ctrl+alt+d") || data === "q") return hide();
	const page = Math.max(1, body.viewportHeight - 1);
	if (matchesKey(data, "up")) body.scrollBy(-1);
	else if (matchesKey(data, "down")) body.scrollBy(1);
	else if (matchesKey(data, "pageUp")) body.scrollBy(-page);
	else if (matchesKey(data, "pageDown")) body.scrollBy(page);
	else if (matchesKey(data, "home")) body.scrollToStart();
	else if (matchesKey(data, "end")) body.scrollToEnd();
	else if (matchesKey(data, "right") || matchesKey(data, "tab")) pick(sel + 1);
	else if (matchesKey(data, "left") || matchesKey(data, "shift+tab")) pick(sel - 1);
	tui.requestRender();
}

function show(ctx: ExtensionContext) {
	if (!capture(ctx)) {
		ctx.ui.notify('Diff panel needs "tuiMode": "fullscreen" in settings.json', "warning");
		return;
	}
	if (shown()) return tui.requestRender();
	const original = tui.layoutRoot[ORIGINAL] ?? tui.layoutRoot; // VStack [transcript, input dock]
	const [main, dock] = original.entries;

	body = new ScrollView(new Lines(diffBody), { scrollbar: "auto" });
	const content = new VStack([
		{ component: new Lines(header) },
		{ component: body, basis: 0, grow: 1, shrink: 1, minSize: 1 },
		{
			component: new Lines((w) => [
				theme.fg("borderMuted", "─".repeat(w)),
				theme.fg("dim", focused() ? " ↑↓ scroll  ←→ file  Esc back  q hide" : " Alt+D focus  Ctrl+Alt+D hide"),
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
	// addChild copies basis once; make it follow terminal width
	Object.defineProperty(split.entries[1], "basis", { get: () => Math.max(40, Math.floor(tui.terminal.columns / 4)) });
	root = new VStack([{ ...main, component: split }, dock]);
	root[ORIGINAL] = original;
	tui.setLayoutRoot(root);
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
	if (!shown()) return;
	unfocus();
	tui.setLayoutRoot(root[ORIGINAL]);
	root = undefined;
}

function toggle(ctx: ExtensionContext) {
	if (shown()) hide();
	else show(ctx);
}

function focusToggle(ctx: ExtensionContext) {
	if (focused()) return unfocus();
	show(ctx);
	if (shown()) focus();
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_e, ctx) => {
		cwd = ctx.cwd;
		originals.clear();
		diffs.clear();
		sel = 0;
		root = undefined;
		if (!capture(ctx)) return;
		// undo a pane left behind by a previous load (e.g. /reload)
		const f = tui.getFocusedComponent();
		if (f?.[PREV_FOCUS]) tui.setFocus(f[PREV_FOCUS]);
		if (tui.layoutRoot[ORIGINAL]) tui.setLayoutRoot(tui.layoutRoot[ORIGINAL]);
	});

	pi.on("tool_call", (event, ctx) => {
		if (event.toolName !== "edit" && event.toolName !== "write") return;
		const abs = resolve(ctx.cwd, String(event.input.path ?? ""));
		if (!originals.has(abs)) originals.set(abs, existsSync(abs) ? readFileSync(abs, "utf8") : null);
	});

	pi.on("tool_result", (event, ctx) => {
		if ((event.toolName !== "edit" && event.toolName !== "write") || event.isError) return;
		const abs = resolve(ctx.cwd, String(event.input.path ?? ""));
		if (!originals.has(abs)) return;
		cwd = ctx.cwd;
		diffs.set(abs, diffOf(abs));
		pick([...diffs.keys()].indexOf(abs));
		if (shown()) tui.requestRender();
	});

	pi.registerShortcut("ctrl+alt+d", { description: "Diff panel: show/hide", handler: (ctx) => toggle(ctx) });
	pi.registerShortcut("alt+d", { description: "Diff panel: focus / back to editor", handler: (ctx) => focusToggle(ctx) });

	pi.registerCommand("diffpanel", {
		description: "Diff side pane: toggle | focus | close",
		handler: async (args, ctx) => {
			const a = args.trim();
			if (a === "close") hide();
			else if (a === "focus") focusToggle(ctx);
			else toggle(ctx);
		},
	});
}
