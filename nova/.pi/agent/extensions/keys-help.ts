/**
 * Alt+/ → popup listing every pi keybinding as currently in effect:
 * built-ins (with ~/.pi/agent/keybindings.json overrides marked ★), extension shortcuts, and raw input hooks.
 * In popup: type to filter, ↑↓ PgUp/PgDn scroll, Esc clears filter / closes, Alt+/ closes.
 */
import { basename } from "node:path";
import { ExtensionRunner, type ExtensionAPI, type Theme } from "@earendil-works/pi-coding-agent";
import { matchesKey, truncateToWidth } from "@earendil-works/pi-tui";

// Extension shortcuts live on pi's ExtensionRunner, which extensions can't reach. Capture it by
// wrapping createContext (runs on every event). Symbol.for keeps this working across /reload.
// ponytail: relies on pi internals; if it breaks, the Extensions section is simply empty.
const RUNNER = Symbol.for("keys-help.runner");
const PATCHED = Symbol.for("keys-help.patched");
const proto = ExtensionRunner.prototype as any;
if (!proto[PATCHED]) {
	const orig = proto.createContext;
	proto.createContext = function (...a: unknown[]) {
		(globalThis as any)[RUNNER] = this;
		return orig.apply(this, a);
	};
	proto[PATCHED] = true;
}

// Bindings made with ctx.ui.onTerminalInput don't register anywhere; list them by hand.
const INPUT_HOOKS: [string, string][] = [["escape escape", "Clear input field when it has text (esc-clear.ts)"]];

type Row = { group: string; key: string; desc: string; custom: boolean };

const fmt = (k: string) =>
	k
		.split(" ")
		.map((c) => c.split("+").map((p) => (p === "escape" ? "Esc" : p[0].toUpperCase() + p.slice(1))).join("+"))
		.join(" ");

function groupOf(id: string): string {
	if (id.startsWith("app.")) return "App";
	const g = id.split(".")[1] ?? "other";
	if (g === "editor" || g === "input") return "Editor";
	if (g === "altScreen") return "Fullscreen";
	return g[0].toUpperCase() + g.slice(1);
}

function collect(kb: any): Row[] {
	const rows: Row[] = [];
	const user = kb.getUserBindings?.() ?? {};
	for (const [id, def] of Object.entries<any>(kb.definitions ?? {})) {
		const keys: string[] = kb.getKeys(id);
		if (keys.length) rows.push({ group: groupOf(id), key: keys.map(fmt).join(" / "), desc: def.description, custom: id in user });
	}
	const runner = (globalThis as any)[RUNNER];
	const resolved = kb.getEffectiveConfig?.() ?? kb.getResolvedBindings();
	for (const [k, s] of runner?.getShortcuts?.(resolved) ?? [])
		rows.push({ group: "Extensions", key: fmt(k), desc: `${s.description ?? ""} · ${basename(s.extensionPath)}`, custom: false });
	for (const [k, d] of INPUT_HOOKS) rows.push({ group: "Input hooks", key: fmt(k), desc: d, custom: true });
	return rows;
}

class KeysHelp {
	scroll = 0;
	q = "";
	constructor(
		private tui: any,
		private th: Theme,
		private rows: Row[],
		private done: () => void,
	) {}

	body(): string[] {
		const th = this.th;
		const q = this.q.toLowerCase();
		const rows = this.rows.filter((r) => `${r.group} ${r.key} ${r.desc}`.toLowerCase().includes(q));
		const kw = Math.min(30, Math.max(...rows.map((r) => r.key.length), 4));
		const out: string[] = [];
		let group = "";
		for (const r of rows) {
			if (r.group !== group) {
				if (group) out.push("");
				out.push(th.fg("mdHeading", ` ${(group = r.group)}`));
			}
			out.push(`  ${th.fg("accent", r.key.padEnd(kw))}  ${r.desc}${r.custom ? th.fg("warning", " ★") : ""}`);
		}
		if (!rows.length) out.push(th.fg("dim", "  (no matches)"));
		return out;
	}

	handleInput(d: string) {
		const page = Math.max(1, Math.floor(this.tui.terminal.rows * 0.85) - 5);
		if (matchesKey(d, "escape")) {
			if (this.q) this.q = "";
			else this.done();
		} else if (matchesKey(d, "alt+/") || matchesKey(d, "ctrl+c")) this.done();
		else if (matchesKey(d, "up")) this.scroll--;
		else if (matchesKey(d, "down")) this.scroll++;
		else if (matchesKey(d, "pageUp")) this.scroll -= page;
		else if (matchesKey(d, "pageDown")) this.scroll += page;
		else if (matchesKey(d, "backspace")) {
			this.q = this.q.slice(0, -1);
			this.scroll = 0;
		} else if (d.length === 1 && d >= " ") {
			this.q += d;
			this.scroll = 0;
		}
		this.tui.requestRender();
	}

	invalidate() {}

	render(w: number): string[] {
		const th = this.th;
		const inner = w - 2;
		const height = Math.max(8, Math.floor(this.tui.terminal.rows * 0.85));
		const lines = this.body();
		const room = height - 4;
		this.scroll = Math.max(0, Math.min(this.scroll, lines.length - room));
		const view = lines.slice(this.scroll, this.scroll + room);
		while (view.length < room) view.push("");
		const b = (s: string) => th.fg("accent", s);
		const row = (s: string) => b("│") + truncateToWidth(s, inner, "…", true) + b("│");
		const title = ` Keybindings · ★ = customized `;
		return [
			b("╭" + truncateToWidth(title + "─".repeat(inner), inner, "") + "╮"),
			row(` ${th.fg("dim", "filter:")} ${this.q}${th.fg("accent", "▏")}`),
			...view.map(row),
			row(th.fg("dim", ` type to filter · ↑↓ PgUp/PgDn scroll · Esc close   ${this.scroll + 1}-${Math.min(this.scroll + room, lines.length)}/${lines.length}`)),
			b("╰" + "─".repeat(inner) + "╯"),
		];
	}
}

export default function (pi: ExtensionAPI) {
	pi.registerShortcut("alt+/", {
		description: "Show all keybindings",
		handler: async (ctx) => {
			if (ctx.mode !== "tui") return;
			await ctx.ui.custom<void>((tui, theme, kb, done) => new KeysHelp(tui, theme, collect(kb), () => done()), {
				overlay: true,
				overlayOptions: { anchor: "center", width: "80%", minWidth: 60 },
			});
		},
	});
}
