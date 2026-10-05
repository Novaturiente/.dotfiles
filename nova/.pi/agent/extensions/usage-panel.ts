/**
 * Right-side pane (25%, min 40 cols): Claude subscription limits + reset times (IST), current context
 * breakdown, and session token/cost totals. Same layout swap as diff-panel.ts and shares its ORIGINAL
 * symbol, so only one side pane is shown at a time. Needs "tuiMode": "fullscreen".
 *   Ctrl+Alt+U / /usagepanel        show / hide
 *   Alt+U / /usagepanel focus       focus pane (opens it if hidden); Alt+U again → back to editor
 *   /usagepanel close               hide
 *   focused: ↑↓ PgUp/PgDn Home/End scroll, r refresh, Esc/Alt+U back to editor, q hide
 */
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { HStack, matchesKey, ScrollView, truncateToWidth, VStack } from "@earendil-works/pi-tui";
import { cachedUsage } from "./claude-usage.ts";
// ponytail: reaches into pi-observational-memory internals; breaks if the plugin renames these
import { rawTokensSinceLastCompaction } from "../npm/node_modules/pi-observational-memory/src/session-ledger/progress.ts";
import { loadConfig, resolveCompactAfterTokens } from "../npm/node_modules/pi-observational-memory/src/config.ts";

const ORIGINAL = Symbol.for("diff-panel.originalRoot");
const PREV_FOCUS = Symbol.for("diff-panel.prevFocus");
const STALE_MS = 2 * 60_000; // shared cache max age while shown (footer uses 5 min)

let api: ExtensionAPI;
let tui: any; // pi's TUI; layoutRoot/setLayoutRoot are fullscreen-renderer internals
let theme: Theme;
let root: any;
let pane: any;
let body: ScrollView;
let timer: ReturnType<typeof setInterval> | null = null;

let currentProvider = "claude";
let usage: any; // usage response
let plan: { sub?: string; tier?: string } = {};
let fetchedAt = 0;
let fetchErr = "";
let loading = false;

type Totals = { calls: number; input: number; output: number; cacheRead: number; cacheWrite: number; cost: number };
let snap:
	| { model: string; cu?: { tokens: number | null; contextWindow: number; percent: number | null }; parts: [string, number][]; totals: Totals; compactions: number; om?: { progress: number; threshold: number } }
	| undefined;

// ---------- data ----------

let backoffUntil = 0;

async function refresh(maxAge = STALE_MS, ctx?: ExtensionContext) {
	if (loading) return;
	loading = true;
	const provider = ctx?.model?.provider === "antigravity" ? "antigravity" : "claude";
	const modelId = ctx?.model?.id ?? "";
	currentProvider = provider;

	if (provider === "antigravity") {
		try {
			const auth = JSON.parse(await readFile(`${homedir()}/.pi/agent/auth.json`, "utf8"))?.antigravity;
			const res = await fetch("https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist", {
				method: "POST",
				headers: {
					Authorization: `Bearer ${auth?.access}`,
					"Content-Type": "application/json",
					"User-Agent": "antigravity/cli/1.2.4 (aidev_client; os_type=linux; arch=amd64; cl=982146307; auth_method=consumer)",
				},
				body: JSON.stringify({ metadata: { ideType: "ANTIGRAVITY", platform: "PLATFORM_UNSPECIFIED", pluginType: "GEMINI" } }),
				signal: AbortSignal.timeout(5_000),
			});
			if (res.ok) {
				const d = await res.json();
				plan = { sub: d.paidTier?.name ?? d.currentTier?.name ?? "Google AI", tier: d.paidTier?.id ?? d.currentTier?.id };
			} else {
				plan = { sub: "Antigravity", tier: auth?.email };
			}
		} catch {
			plan = { sub: "Antigravity", tier: undefined };
		}
	} else {
		try {
			const c = JSON.parse(await readFile(`${homedir()}/.claude/.credentials.json`, "utf8")).claudeAiOauth;
			plan = { sub: c.subscriptionType, tier: c.rateLimitTier };
		} catch {
			plan = {};
		}
	}

	const r = await cachedUsage(maxAge, provider, modelId);
	if (r.data) usage = r.data;
	fetchedAt = r.at;
	fetchErr = r.err ?? "";
	backoffUntil = r.backoffUntil ?? 0;
	loading = false;
	if (shown()) tui.requestRender();
}

type Limit = { label: string; pct: number; reset: string | null };
function limits(u: any): Limit[] {
	if (currentProvider === "antigravity") {
		const list: Limit[] = [];
		for (const group of u?.groups || []) {
			for (const bucket of group.buckets || []) {
				const rem = bucket.remainingFraction != null ? Math.round(bucket.remainingFraction * 100) : null;
				const usedPct = rem != null ? Math.max(0, Math.min(100, 100 - rem)) : 0;
				list.push({
					label: `${group.displayName} · ${String(bucket.displayName || "").replace(" Remaining", "")}`,
					pct: usedPct,
					reset: bucket.resetTime ?? null,
				});
			}
		}
		return list;
	}
	if (Array.isArray(u?.limits) && u.limits.length)
		return u.limits.map((l: any) => ({
			label:
				l.kind === "session"
					? "Session (5h)"
					: l.kind === "weekly_all"
						? "Weekly · all models"
						: `Weekly · ${l.scope?.model?.display_name ?? l.scope?.surface ?? l.kind}`,
			pct: l.percent ?? 0,
			reset: l.resets_at,
		}));
	const old: [string, any][] = [
		["Session (5h)", u?.five_hour],
		["Weekly · all models", u?.seven_day],
		["Weekly · Opus", u?.seven_day_opus],
		["Weekly · Sonnet", u?.seven_day_sonnet],
	];
	return old.filter(([, w]) => w).map(([label, w]) => ({ label, pct: w.utilization ?? 0, reset: w.resets_at }));
}

const ROLE: Record<string, string> = {
	user: "User msgs",
	assistant: "Assistant msgs",
	toolResult: "Tool results",
	bashExecution: "Bash (!cmd)",
	custom: "Extension msgs",
	compactionSummary: "Summaries",
	branchSummary: "Summaries",
};
const chars = (x: unknown) => (typeof x === "string" ? x : (JSON.stringify(x ?? "") ?? "")).length;
// images count as ~1.5k tokens, not their base64 length
const size = (c: unknown): number =>
	Array.isArray(c) ? c.reduce((s: number, b: any) => s + (b?.type === "image" ? 6000 : chars(b)), 0) : chars(c);

function takeSnap(ctx: ExtensionContext) {
	const sm: any = ctx.sessionManager;
	const parts = new Map<string, number>();
	const add = (k: string, n: number) => parts.set(k, (parts.get(k) ?? 0) + n);
	add("System prompt", chars(ctx.getSystemPrompt()));
	const active = new Set(api.getActiveTools());
	const tools = api.getAllTools().filter((t) => active.has(t.name));
	add(`Tools (${tools.length})`, tools.reduce((s, t) => s + chars({ n: t.name, d: t.description, p: t.parameters }), 0));
	for (const e of sm.buildContextEntries()) {
		if (e.type === "message") add(ROLE[e.message.role] ?? e.message.role, size(e.message.content ?? e.message));
		else if (e.type === "compaction" || e.type === "branch_summary") add("Summaries", chars(e.summary));
		else if (e.type === "custom_message") add("Extension msgs", size(e.content));
	}
	const cu = ctx.getContextUsage();
	const sum = [...parts.values()].reduce((a, b) => a + b, 0) || 1;
	// ponytail: chars→tokens by one ratio (scaled to the real total when known); per-part split is approximate
	const k = cu?.tokens ? cu.tokens / sum : 0.25;

	const totals: Totals = { calls: 0, input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0 };
	let compactions = 0;
	for (const e of sm.getEntries()) {
		if (e.type === "compaction") compactions++;
		const u = e.type === "message" && e.message.role === "assistant" ? e.message.usage : e.type === "usage" || e.type === "compaction" ? e.usage : undefined;
		if (!u) continue;
		if (e.type === "message") totals.calls++;
		totals.input += u.input ?? 0;
		totals.output += u.output ?? 0;
		totals.cacheRead += u.cacheRead ?? 0;
		totals.cacheWrite += u.cacheWrite ?? 0;
		totals.cost += u.cost?.total ?? 0;
	}
	const om = {
		progress: rawTokensSinceLastCompaction(sm.getBranch()),
		threshold: resolveCompactAfterTokens(loadConfig(ctx.cwd), ctx.model?.contextWindow),
	};
	snap = {
		om,
		model: ctx.model?.name ?? ctx.model?.id ?? "no model",
		cu,
		parts: [...parts].map(([n, c]) => [n, Math.round(c * k)] as [string, number]).sort((a, b) => b[1] - a[1]),
		totals,
		compactions,
	};
}

// ---------- rendering ----------

const tier = (v: number, s: string) =>
	`\x1b[38;2;${(v >= 90 ? [255, 95, 95] : v >= 70 ? [255, 135, 0] : v >= 50 ? [255, 215, 95] : [95, 215, 95]).join(";")}m${s}\x1b[39m`;
const bar = (pct: number, n: number) => {
	const f = Math.round((Math.min(100, Math.max(0, pct)) / 100) * n);
	return tier(pct, "█".repeat(f)) + theme.fg("dim", "░".repeat(n - f));
};
const fmt = (n: number) => (n >= 1e6 ? `${(n / 1e6).toFixed(2)}M` : n >= 1e3 ? `${(n / 1e3).toFixed(1)}k` : String(Math.round(n)));
const dur = (ms: number) => {
	if (ms <= 0) return "now";
	const m = Math.round(ms / 60_000);
	const d = Math.floor(m / 1440);
	const h = Math.floor((m % 1440) / 60);
	return d ? `${d}d ${h}h` : h ? `${h}h ${m % 60}m` : `${m}m`;
};
const IST = new Intl.DateTimeFormat("en-GB", { timeZone: "Asia/Kolkata", weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit", hour12: false });
const resetText = (iso: string | null) => (iso ? `${IST.format(new Date(iso))} IST · in ${dur(Date.parse(iso) - Date.now())}` : "—");

function bodyLines(w: number): string[] {
	const th = theme;
	const out: string[] = [];
	const head = (s: string) => out.push("", " " + th.bold(th.fg("accent", s)));
	const kv = (k: string, v: string) => out.push(`  ${th.fg("muted", k.padEnd(15))}${v}`);
	const bw = Math.max(8, w - 10);

	head("PLAN");
	kv("Subscription", plan.sub ?? "?");
	kv("Rate tier", (plan.tier ?? "?").replace(/^default_claude_/, ""));

	head("LIMITS");
	if (!usage) out.push(th.fg(fetchErr ? "error" : "dim", `  ${fetchErr || "loading…"}`));
	for (const l of limits(usage)) {
		out.push(`  ${th.fg("text", l.label)}`);
		out.push(`  ${bar(l.pct, bw)} ${tier(l.pct, `${Math.round(l.pct)}%`)}`);
		out.push(th.fg("dim", `  resets ${resetText(l.reset)}`));
	}
	const sp = usage?.spend;
	if (sp) {
		const money = (m: any) => (m ? `${(m.amount_minor / 10 ** m.exponent).toFixed(2)} ${m.currency}` : "—");
		kv("Extra usage", sp.enabled ? `${money(sp.used)} / ${money(sp.limit)}` : th.fg("dim", "off"));
	}
	const rows = (usage?.seven_day_breakdown?.rows ?? []).filter((r: any) => r.percent > 0);
	if (rows.length) kv("Week by app", rows.map((r: any) => `${r.display_name} ${r.percent}%`).join(" · "));
	const wait = backoffUntil - Date.now();
	out.push(
		th.fg("dim", fetchedAt ? `  updated ${dur(Date.now() - fetchedAt)} ago`.replace("now ago", "just now") : "  never fetched") +
			(usage && fetchErr ? th.fg("error", ` · ${fetchErr.replace("usage endpoint ", "")}`) : "") +
			(fetchErr && wait > 0 ? th.fg("dim", ` · retry in ${dur(wait)}`) : ""),
	);

	if (!snap) return out;
	const { cu, parts, totals: t } = snap;
	head(`CONTEXT · ${snap.model}`);
	if (cu?.tokens != null && cu.percent != null) {
		out.push(`  ${bar(cu.percent, bw)} ${tier(cu.percent, `${Math.round(cu.percent)}%`)}`);
		out.push(th.fg("dim", `  ${fmt(cu.tokens)} / ${fmt(cu.contextWindow)} tokens`));
	} else out.push(th.fg("dim", `  total unknown until next response${cu ? ` · window ${fmt(cu.contextWindow)}` : ""}`));
	for (const [name, tok] of parts) kv(name, `~${fmt(tok)}` + (cu?.contextWindow ? th.fg("dim", `  ${((tok / cu.contextWindow) * 100).toFixed(1)}%`) : ""));
	if (cu?.tokens != null) kv("Free", fmt(cu.contextWindow - cu.tokens));
	if (snap.om) {
		const { progress, threshold } = snap.om;
		const pct = (progress / threshold) * 100;
		head("OM AUTO-COMPACT");
		out.push(`  ${bar(pct, bw)} ${tier(pct, `${Math.round(pct)}%`)}`);
		out.push(th.fg("dim", `  ~${fmt(progress)} / ${fmt(threshold)} est. tokens · checked when agent settles`));
	}

	head("SESSION");
	kv("API calls", String(t.calls));
	kv("Input", fmt(t.input));
	kv("Output", fmt(t.output));
	kv("Cache read", fmt(t.cacheRead));
	kv("Cache write", fmt(t.cacheWrite));
	const prompt = t.input + t.cacheRead + t.cacheWrite;
	if (prompt) kv("Cache hit", `${Math.round((t.cacheRead / prompt) * 100)}%`);
	kv("Cost (API eq.)", `$${t.cost.toFixed(2)}`);
	kv("Compactions", String(snap.compactions));
	return out;
}

// ---------- layout (mirrors diff-panel.ts) ----------

class Lines {
	constructor(private fn: (w: number) => string[]) {}
	render(w: number) {
		return this.fn(w).map((l) => truncateToWidth(l, w, "…"));
	}
	invalidate() {}
}

function capture(ctx: ExtensionContext): boolean {
	if (ctx.mode !== "tui") return false;
	ctx.ui.setWidget("usage-panel-probe", (t, th) => {
		tui = t;
		theme = th;
		return { render: () => [], invalidate() {} };
	});
	ctx.ui.setWidget("usage-panel-probe", undefined);
	return typeof tui?.setLayoutRoot === "function" && !!tui.layoutRoot;
}

const shown = () => !!root && tui?.layoutRoot === root;
const focused = () => shown() && tui.getFocusedComponent() === pane;

function onKey(data: string) {
	if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c") || matchesKey(data, "alt+u")) return unfocus();
	if (matchesKey(data, "ctrl+alt+u") || data === "q") return hide();
	const page = Math.max(1, body.viewportHeight - 1);
	if (data === "r") refresh();
	else if (matchesKey(data, "up")) body.scrollBy(-1);
	else if (matchesKey(data, "down")) body.scrollBy(1);
	else if (matchesKey(data, "pageUp")) body.scrollBy(-page);
	else if (matchesKey(data, "pageDown")) body.scrollBy(page);
	else if (matchesKey(data, "home")) body.scrollToStart();
	else if (matchesKey(data, "end")) body.scrollToEnd();
	tui.requestRender();
}

function show(ctx: ExtensionContext) {
	if (!capture(ctx)) {
		ctx.ui.notify('Usage panel needs "tuiMode": "fullscreen" in settings.json', "warning");
		return;
	}
	takeSnap(ctx);
	refresh(STALE_MS, ctx); // shared cache decides whether to hit the network
	if (shown()) return tui.requestRender();
	// another side pane (diff-panel) may hold focus; hand focus back before swapping it out
	const f = tui.getFocusedComponent();
	if (f?.[PREV_FOCUS]) tui.setFocus(f[PREV_FOCUS]);
	const original = tui.layoutRoot[ORIGINAL] ?? tui.layoutRoot; // VStack [transcript, input dock]
	const [main, dock] = original.entries;

	body = new ScrollView(new Lines(bodyLines), { scrollbar: "auto" });
	const title = () => ` ${theme.bold(theme.fg("accent", currentProvider === "antigravity" ? "ANTIGRAVITY QUOTA" : "CLAUDE USAGE"))}`;
	const content = new VStack([
		{ component: new Lines(() => [title()]) },
		{ component: body, basis: 0, grow: 1, shrink: 1, minSize: 1 },
		{
			component: new Lines((w) => [
				theme.fg("borderMuted", "─".repeat(w)),
				theme.fg("dim", focused() ? " ↑↓ scroll  r refresh  Esc back  q hide" : " Alt+U focus  Ctrl+Alt+U hide"),
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
	// live countdowns + stale refetch while visible
	timer ??= setInterval(() => {
		if (!shown()) return;
		refresh(STALE_MS, ctx);
		tui.requestRender();
	}, 30_000);
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

export default function (pi: ExtensionAPI) {
	api = pi;
	pi.on("session_start", (_e, ctx) => {
		root = undefined;
		snap = undefined;
		if (!capture(ctx)) return;
		// undo a pane left behind by a previous load (e.g. /reload)
		const f = tui.getFocusedComponent();
		if (f?.[PREV_FOCUS]) tui.setFocus(f[PREV_FOCUS]);
		if (tui.layoutRoot[ORIGINAL]) tui.setLayoutRoot(tui.layoutRoot[ORIGINAL]);
	});
	for (const ev of ["turn_end", "agent_end", "session_compact", "model_select"] as const)
		pi.on(ev as any, (_e: unknown, ctx: ExtensionContext) => {
			if (!shown()) return;
			takeSnap(ctx);
			refresh(STALE_MS, ctx); // picks up provider live file or quota; network only if stale
			tui.requestRender();
		});
	pi.on("session_shutdown", () => {
		if (timer) clearInterval(timer);
		timer = null;
	});

	pi.registerShortcut("ctrl+alt+u", { description: "Usage panel: show/hide", handler: (ctx) => toggle(ctx) });
	pi.registerShortcut("alt+u", { description: "Usage panel: focus / back to editor", handler: (ctx) => focusToggle(ctx) });
	pi.registerCommand("usagepanel", {
		description: "Claude usage side pane: toggle | focus | close",
		handler: async (args, ctx) => {
			const a = args.trim();
			if (a === "close") hide();
			else if (a === "focus") focusToggle(ctx);
			else toggle(ctx);
		},
	});
}
