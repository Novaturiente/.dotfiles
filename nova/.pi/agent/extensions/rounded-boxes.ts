// Rounded boxes for user messages and the input editor, plus alt+c to copy the input.
// ponytail: patches pi internals (UserMessageComponent, InteractiveMode.setCustomEditorComponent);
// re-check after pi upgrades if boxes disappear.
import { copyToClipboard, InteractiveMode, UserMessageComponent, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const ANSI = /\x1b\[[0-9;]*m/g;
const OSC_START = "\x1b]133;A\x07";
const OSC_END = "\x1b]133;B\x07\x1b]133;C\x07";
type Color = (s: string) => string;

let ui: { theme: { fg(token: string, s: string): string } } | undefined;
const userBorder: Color = (s) => ui?.theme.fg("border", s) ?? s;

const pad = (s: string, w: number) => {
	const vw = visibleWidth(s);
	return vw > w ? truncateToWidth(s, w, "") : s + " ".repeat(w - vw);
};

const edge = (l: string, r: string, label: string, w: number, c: Color) => {
	const lab = label ? truncateToWidth(` ${label} `, Math.max(0, w - 4), "") : "";
	return c(`${l}─`) + lab + c(`${"─".repeat(Math.max(0, w - 3 - visibleWidth(lab)))}${r}`);
};

const box = (inner: string[], w: number, c: Color, top = "", bottom = "") => [
	edge("╭", "╮", top, w, c),
	...inner.map((l) => c("│") + pad(l, w - 2) + c("│")),
	edge("╰", "╯", bottom, w, c),
];

// User messages: drop the background, draw a rounded border instead.
const UM = UserMessageComponent.prototype as any;
if (!UM.__rounded) {
	UM.__rounded = true;
	const rebuild = UM.rebuild;
	const render = UM.render;
	UM.rebuild = function () {
		rebuild.call(this);
		const md = this.children[0];
		if (md?.defaultTextStyle) {
			md.defaultTextStyle = { ...md.defaultTextStyle, bgColor: undefined };
			md.paddingY = 0;
		}
	};
	UM.render = function (width: number) {
		if (width < 4) return render.call(this, width);
		const inner = render.call(this, width - 2).map((l: string) => l.replace(OSC_START, "").replace(OSC_END, ""));
		const out = box(inner, width, userBorder);
		out[0] = OSC_START + out[0];
		out[out.length - 1] = OSC_END + out[out.length - 1];
		return out;
	};
}

// Editor: replace its straight top/bottom rules with a rounded box. Works on top of
// pi-powerline-footer's editor because it wraps whatever editor instance gets installed.
const strip = (s: string) => s.replace(ANSI, "");
const isRule = (l: string) => /^\s?[─↑↓]/.test(strip(l)) && /─{3,}/.test(strip(l));
const ruleLabel = (l: string) => strip(l).trim().replace(/^─+|─+$/g, "").trim().replace(/^[↑↓]─+$/, (m) => m[0]);

function boxEditor(ed: any) {
	if (!ed || ed.__rounded) return;
	ed.__rounded = true;
	const orig = ed.render.bind(ed);
	const c: Color = (s) => (typeof ed.borderColor === "function" ? ed.borderColor(s) : s);
	ed.render = (width: number): string[] => {
		if (width < 8) return orig(width);
		const lines: string[] = orig(width - 2);
		let bottom = -1;
		for (let i = lines.length - 1; i >= 1; i--) if (isRule(lines[i])) { bottom = i; break; }
		if (!isRule(lines[0] ?? "") || bottom < 1) return orig(width);
		return [
			...box(lines.slice(1, bottom), width, c, ruleLabel(lines[0]), ruleLabel(lines[bottom])),
			...lines.slice(bottom + 1).map((l) => ` ${l}`), // autocomplete list, aligned inside the box
		];
	};
}

const IM = InteractiveMode.prototype as any;
if (!IM.__rounded) {
	IM.__rounded = true;
	const set = IM.setCustomEditorComponent;
	IM.setCustomEditorComponent = function (factory: unknown) {
		set.call(this, factory);
		boxEditor(this.editor);
		this.ui?.requestRender();
	};
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_e, ctx) => {
		ui = ctx.ui as any;
	});

	pi.registerShortcut("alt+c", {
		description: "Copy input field text",
		handler: async (ctx) => {
			const text = ctx.ui.getEditorText();
			if (!text) return ctx.ui.notify("Input is empty", "info");
			await copyToClipboard(text);
			ctx.ui.notify("Input copied", "info");
		},
	});
}
