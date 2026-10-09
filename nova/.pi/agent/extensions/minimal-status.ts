/**
 * Minimal animated statusline, drawn as a below-editor widget.
 * pi-powerline-footer still owns the editor/bash mode; its status row is emptied via
 * `powerline.layout` (left/right/secondary = []) in settings.json.
 * Animations: shimmer on model name while working, eased + colour-graded context bar,
 * brief white pulse on segments that change (git, model).
 */
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type RGB = [number, number, number];
const rgb = (h: string) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)) as RGB;
const mix = (a: RGB, b: RGB, t: number) => a.map((v, i) => Math.round(v + (b[i] - v) * t)) as RGB;
const paint = (c: RGB, s: string) => `\x1b[38;2;${c.join(";")}m${s}\x1b[39m`;

// ponytail: Catppuccin Mocha hard-coded, not wired to scripts/theme.sh palettes.
const C = {
	text: rgb("#cdd6f4"), dim: rgb("#7f849c"), sep: rgb("#45475a"), path: rgb("#94e2d5"),
	git: rgb("#a6e3a1"), dirty: rgb("#f9e2af"), model: rgb("#cba6f7"), hi: rgb("#f5e0dc"),
	green: rgb("#a6e3a1"), yellow: rgb("#f9e2af"), red: rgb("#f38ba8"), white: rgb("#ffffff"),
};
const load = (p: number) => (p < 60 ? mix(C.green, C.yellow, p / 60) : mix(C.yellow, C.red, Math.min(1, (p - 60) / 30)));
const THINK: Record<string, string> = { off: "", minimal: "min", low: "low", medium: "med", high: "high", xhigh: "xhi", max: "max" };
const PULSE_MS = 900;
const BAR = 8;

const fmt = (ms: number) => {
	const s = Math.floor(ms / 1000);
	if (s < 60) return `${s}s`;
	if (s < 3600) return `${Math.floor(s / 60)}m${String(s % 60).padStart(2, "0")}`;
	return `${Math.floor(s / 3600)}h${String(Math.floor(s / 60) % 60).padStart(2, "0")}`;
};

export default function (pi: ExtensionAPI) {
	let ctx: ExtensionContext | undefined;
	let tui: { requestRender(): void } | undefined;
	let sessionStart = Date.now();
	let turnStart = 0;
	let branch = "";
	let dirty = false;
	let ctxTarget = 0;
	let ctxShown = 0;
	const pulses = new Map<string, number>();
	let fast: ReturnType<typeof setInterval> | undefined;
	let slow: ReturnType<typeof setInterval> | undefined;

	const animating = () =>
		turnStart > 0 || Math.abs(ctxTarget - ctxShown) > 0.1 || [...pulses.values()].some((t) => Date.now() - t < PULSE_MS);
	// Fast loop only runs while something moves; idle cost is the 1s clock tick.
	const kick = () => {
		fast ??= setInterval(() => {
			ctxShown += (ctxTarget - ctxShown) * 0.15;
			if (Math.abs(ctxTarget - ctxShown) <= 0.1) ctxShown = ctxTarget;
			tui?.requestRender();
			if (!animating()) {
				clearInterval(fast);
				fast = undefined;
			}
		}, 60);
	};
	const pulse = (k: string) => {
		pulses.set(k, Date.now());
		kick();
	};
	const pc = (k: string, base: RGB) => {
		const t = Math.max(0, 1 - (Date.now() - (pulses.get(k) ?? 0)) / PULSE_MS);
		return t > 0 ? mix(base, C.white, t * t * 0.8) : base;
	};

	const shimmer = (s: string) => {
		const base = pc("model", C.model);
		if (!turnStart) return paint(base, s);
		const pos = ((Date.now() / 70) % (s.length + 8)) - 4;
		return [...s].map((ch, i) => paint(mix(base, C.hi, Math.max(0, 1 - Math.abs(i - pos) / 3)), ch)).join("");
	};

	const bar = (p: number) => {
		const n = Math.min(BAR, Math.max(0, Math.round((p / 100) * BAR)));
		return paint(load(p), "━".repeat(n)) + paint(C.sep, "━".repeat(BAR - n)) + " " + paint(load(p), `${Math.round(p)}%`);
	};

	const render = (width: number): string[] => {
		if (!ctx) return [];
		const now = Date.now();
		const sep = paint(C.sep, " · ");

		const wt = ctx.cwd.match(/([^/]+)\/\.claude\/worktrees\/([^/]+)/);
		let path = wt ? `${wt[1]}:${wt[2]}` : ctx.cwd.replace(process.env.HOME ?? "\0", "~");
		if (path.length > 28) path = `…/${path.split("/").slice(-2).join("/")}`;
		let left = paint(C.path, ` ${path}`);
		if (branch) left += sep + paint(pc("git", dirty ? C.dirty : C.git), ` ${branch}${dirty ? "*" : ""}`);

		const model = (ctx.model?.id ?? "no model").replace(/^claude-/, "");
		const think = THINK[pi.getThinkingLevel()] ?? "";
		const time =
			paint(C.dim, "󱎫 ") + paint(C.text, fmt(now - sessionStart)) +
			(turnStart ? paint(C.model, "  󰔟 ") + paint(C.text, fmt(now - turnStart)) : "");
		const parts = [
			{ p: 4, s: shimmer(model) + (think ? paint(C.dim, ` ${think}`) : "") },
			{ p: 3, s: bar(ctxShown) },
			{ p: 2, s: time },
		];

		const rightOf = () => parts.map((x) => x.s).join(sep);
		while (parts.length > 1 && visibleWidth(left) + visibleWidth(rightOf()) + 4 > width) {
			parts.splice(parts.indexOf(parts.reduce((a, b) => (b.p < a.p ? b : a))), 1);
		}
		const right = rightOf();
		const gap = Math.max(1, width - 2 - visibleWidth(left) - visibleWidth(right));
		return [truncateToWidth(` ${left}${" ".repeat(gap)}${right} `, width, "")];
	};

	const refreshCtx = (c: ExtensionContext) => {
		ctx = c;
		ctxTarget = c.getContextUsage()?.percent ?? 0;
		kick();
	};
	const refreshGit = async (c: ExtensionContext) => {
		const r = await pi.exec("git", ["status", "--porcelain=v1", "-b"], { cwd: c.cwd }).catch(() => undefined);
		const lines = r?.code === 0 ? r.stdout.split("\n").filter(Boolean) : [];
		const b = lines[0]?.slice(3).replace(/^No commits yet on /, "").split("...")[0].split(" ")[0] ?? "";
		const d = lines.length > 1;
		if (b !== branch || d !== dirty) {
			if (branch || dirty) pulse("git");
			branch = b;
			dirty = d;
			tui?.requestRender();
		}
	};
	const refreshAll = (c: ExtensionContext) => {
		refreshCtx(c);
		void refreshGit(c);
	};

	pi.on("session_start", (_e, c) => {
		sessionStart = Date.now();
		refreshAll(c);
		if (c.mode !== "tui") return;
		slow ??= setInterval(() => tui?.requestRender(), 1000);
		c.ui.setWidget("minimal-status", (t) => {
			tui = t;
			return { render, invalidate() {} };
		}, { placement: "belowEditor" });
	});
	pi.on("agent_start", (_e, c) => {
		ctx = c;
		turnStart = Date.now();
		kick();
	});
	pi.on("turn_end", (_e, c) => {
		refreshCtx(c);
		void refreshGit(c);
	});
	pi.on("agent_settled", (_e, c) => {
		turnStart = 0;
		refreshAll(c);
	});
	pi.on("model_select", (_e, c) => {
		pulse("model");
		refreshAll(c);
	});
	pi.on("session_compact", (_e, c) => refreshCtx(c));
	pi.on("session_shutdown", () => {
		if (fast) clearInterval(fast);
		if (slow) clearInterval(slow);
		fast = slow = undefined;
		tui = undefined;
	});
}
