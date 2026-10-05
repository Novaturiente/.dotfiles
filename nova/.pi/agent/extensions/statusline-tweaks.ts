/**
 * Status line tweaks:
 * 1. pi-lens widget renders after the footer, so it never splits the two powerline rows
 *    (powerline-top is a below-editor widget, its 2nd row is the footer; pi-lens landed in between).
 * 2. "ctx" status: context-window % colored green <50 · yellow <70 · orange <90 · red ≥90
 *    (shown via powerline customItems "custom:ctx", replacing the 3-tier built-in context_pct).
 * ponytail: (1) patches InteractiveMode internals (renderWidgetContainer / setExtensionFooter).
 */
import { type ExtensionAPI, type ExtensionContext, InteractiveMode } from "@earendil-works/pi-coding-agent";

const hex = (h: string, s: string) =>
	`\x1b[38;2;${parseInt(h.slice(1, 3), 16)};${parseInt(h.slice(3, 5), 16)};${parseInt(h.slice(5, 7), 16)}m${s}\x1b[39m`;
export const tier = (p: number, s: string) =>
	hex(p >= 90 ? "#f38ba8" : p >= 70 ? "#fab387" : p >= 50 ? "#f9e2af" : "#a6e3a1", s);

// --- 1. pi-lens after footer ---
const ORIG = Symbol.for("statusline-tweaks.orig");
const LENS = Symbol.for("statusline-tweaks.lens");
const proto = (InteractiveMode as any).prototype;
proto[ORIG] ??= { rwc: proto.renderWidgetContainer, sef: proto.setExtensionFooter };
const { rwc, sef } = proto[ORIG];

function syncLens(self: any) {
	const lens = self.extensionWidgetsBelow?.get("pi-lens");
	const fc = self.footerContainer;
	if (!fc) return;
	fc.children = fc.children.filter((c: any) => !c[LENS]);
	if (lens) {
		lens[LENS] = true;
		fc.children.push(lens);
	}
}

proto.renderWidgetContainer = function (container: any, widgets: Map<string, any>, ...rest: unknown[]) {
	if (container !== this.widgetContainerBelow || !widgets.has("pi-lens")) return rwc.call(this, container, widgets, ...rest);
	const others = new Map([...widgets].filter(([k]) => k !== "pi-lens"));
	rwc.call(this, container, others, ...rest);
	syncLens(this);
};
// --- 3. compact ponytail status: "○ 🐴 ponytail: ⚡ FULL" → "○ 🐴:⚡" ---
proto[ORIG].ses ??= proto.setExtensionStatus;
const ses = proto[ORIG].ses;
proto.setExtensionStatus = function (key: string, text?: string) {
	if (key === "ponytail" && text) {
		const i = text.indexOf(" 🐴 ");
		const icon = text.match(/🌿|⚡|🔥/u)?.[0];
		if (i >= 0 && icon) text = `${text.slice(0, i)} 🐴:${icon}`;
	}
	return ses.call(this, key, text);
};

proto.setExtensionFooter = function (...a: unknown[]) {
	const r = sef.apply(this, a);
	syncLens(this);
	return r;
};

// --- 2. colored context % + bar: "━━━━──────── 42%" ---
const BAR = 10;
export const ctxBar = (p: number) => {
	const n = Math.min(BAR, Math.max(0, Math.round((p / 100) * BAR)));
	return tier(p, "━".repeat(n)) + hex("#45475a", "━".repeat(BAR - n)) + " " + tier(p, `${Math.round(p)}%`);
};
function ctxStatus(ctx: ExtensionContext) {
	if (!ctx.hasUI) return;
	const u = ctx.getContextUsage();
	ctx.ui.setStatus("ctx", u?.percent == null ? ctx.ui.theme.fg("dim", "?") : ctxBar(u.percent));
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_e, ctx) => {
		// re-run renderWidgets so the patch applies to widgets mounted before this loaded
		ctx.ui.setWidget("statusline-tweaks-probe", () => ({ render: () => [], invalidate() {} }));
		ctx.ui.setWidget("statusline-tweaks-probe", undefined);
		ctxStatus(ctx);
	});
	for (const ev of ["turn_end", "agent_end", "session_compact", "model_select"] as const) pi.on(ev as any, (_e: unknown, ctx: ExtensionContext) => ctxStatus(ctx));
}
