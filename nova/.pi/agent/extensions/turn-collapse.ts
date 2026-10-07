/**
 * Collapse finished turns: once the agent finishes (or a newer prompt exists), each turn shows only
 *   your prompt · "▸ N tool calls · thinking … click to expand" · final reply text (thinking stripped).
 * User-facing parts stay visible and split the turn into several collapsed sections:
 *   the reply ending each agent run (last text before a message with no tool call), background-task
 *   notifications, text right before a question tool (ask_user_question etc.), the question/answer itself.
 * Click the ▸ line to expand, click ▾ to collapse again. Alt+O flips every past turn.
 * Fullscreen tuiMode only. Nothing is removed: this only changes what the chat container renders.
 * ponytail: patches pi's chat Container.render (internal); a pi update may need this revisited.
 */
import {
	AssistantMessageComponent,
	CustomMessageComponent,
	type ExtensionAPI,
	type ExtensionContext,
	type Theme,
	ToolExecutionComponent,
	UserMessageComponent,
} from "@earendil-works/pi-coding-agent";
import { MouseRegion, Spacer, Text } from "@earendil-works/pi-tui";

const TOKEN = Symbol(); // per module load, so /reload re-patches with fresh code
const PATCH = Symbol.for("turn-collapse.patch");
let tui: any;
let theme: Theme;
let allExpanded = false;
let busy = false; // agent running → keep the live turn open
type Comp = { render(width: number): string[] };
let flipped = new WeakSet<Comp>(); // sections (keyed by the visible part after them) toggled against allExpanded
let clones = new WeakMap<object, { msg: any; comp: any }>();

const isOpen = (u: Comp) => flipped.has(u) !== allExpanded;
function flip(u: Comp) {
	if (flipped.has(u)) flipped.delete(u);
	else flipped.add(u);
	tui?.requestRender();
}

const textOf = (m: any) => (m?.content ?? []).some((c: any) => c.type === "text" && c.text.trim());

/** Final reply without thinking; cached so it isn't rebuilt every frame. */
function replyClone(a: any) {
	const hit = clones.get(a);
	if (hit && hit.msg === a.lastMessage) return hit.comp;
	const msg = { ...a.lastMessage, content: a.lastMessage.content.filter((c: any) => c.type === "text") };
	const comp = new AssistantMessageComponent(msg, true, a.markdownTheme, a.hiddenThinkingLabel, a.outputPad, a.markdownTransformers);
	clones.set(a, { msg: a.lastMessage, comp });
	return comp;
}

const line = (text: string, onClick: () => void) =>
	new MouseRegion(new Text(text, 1, 0), (e: any) => {
		if (e.type !== "click" || e.button !== "left") return undefined;
		onClick();
		return { handled: true };
	});

const isAssistant = (c: any) => c instanceof AssistantMessageComponent;
const hasThinking = (a: any) => a.lastMessage?.content?.some((c: any) => c.type === "thinking" && c.thinking.trim());
// tools that talk to the user; ponytail: name heuristic, extend the regex for new question tools
const isAsk = (c: any) => c instanceof ToolExecutionComponent && /ask_user|question/i.test((c as any).toolName ?? "");

const hasCall = (a: any) => a.lastMessage?.content?.some((c: any) => c.type === "toolCall");
const isNotice = (c: any) => c instanceof CustomMessageComponent && (c as any).message?.customType === "background-task-notification";

/** User-facing parts of a turn: the reply ending each agent run,
 *  question tools, and the text that introduced each question. */
function anchorsOf(rest: any[]): Set<any> {
	const anchors = new Set<any>();
	let lastText: any;
	rest.forEach((c, i) => {
		if (isAssistant(c)) {
			if (textOf(c.lastMessage)) lastText = c;
			// no tool call → run ends here; its last text-bearing message is for the user
			if (!hasCall(c) && lastText) {
				anchors.add(lastText);
				lastText = undefined;
			}
			return;
		}
		// deep pass continues the turn → keep the reply before it visible too
		if (c instanceof CustomMessageComponent && (c as any).message?.customType === "impeccable-deep-pass") {
			const prev = rest.slice(0, i).reverse().find(isAssistant);
			if (prev && textOf(prev.lastMessage)) anchors.add(prev);
			return;
		}
		if (!isAsk(c)) return;
		anchors.add(c);
		const caller = rest.slice(0, i).reverse().find(isAssistant); // message that issued the question call
		if (caller && textOf(caller.lastMessage)) anchors.add(caller);
	});
	if (lastText) anchors.add(lastText); // turn ended mid-run (aborted/error)
	return anchors;
}

/** Components to show for one finished turn (turn[0] is the user message). */
function viewTurn(turn: any[]): any[] {
	const [user, ...rest] = turn;
	const anchors = anchorsOf(rest);
	const out: any[] = [user];
	let seg: any[] = [];
	// each run of hidden items before an anchor (or turn end) becomes its own collapsible section
	for (const c of [...rest, null]) {
		if (c && !anchors.has(c)) {
			seg.push(c);
			continue;
		}
		const key = c ?? user;
		const tail = seg.at(-1) instanceof Spacer ? [seg.pop()] : [];
		const as = seg.filter(isAssistant);
		const tools = seg.filter((x) => x instanceof ToolExecutionComponent).length;
		const thinking = (isAssistant(c) && hasThinking(c)) || as.some(hasThinking);
		const notes = as.filter((a) => textOf(a.lastMessage)).length;
		const notices = seg.filter(isNotice).length;
		const anchor = c ? [c] : [];
		if (!tools && !thinking && !notes && !notices) out.push(...seg, ...tail, ...anchor);
		else if (isOpen(key)) out.push(line(theme.fg("dim", "▾ collapse"), () => flip(key)), ...seg, ...tail, ...anchor);
		else {
			const bits = [tools && `${tools} tool call${tools === 1 ? "" : "s"}`, thinking && "thinking", notes && `${notes} note${notes === 1 ? "" : "s"}`, notices && `${notices} bg task${notices === 1 ? "" : "s"}`];
			const summary = theme.fg("dim", `▸ ${bits.filter(Boolean).join(" · ")} · click to expand`);
			out.push(new Spacer(1), line(summary, () => flip(key)), ...(c ? [isAssistant(c) ? replyClone(c) : c] : tail));
		}
		seg = [];
	}
	return out;
}

function render(this: any, width: number): string[] {
	const kids: any[] = this.children;
	const users = kids.flatMap((c, i) => (c instanceof UserMessageComponent ? [i] : []));
	const shown: any[] = [];
	for (let i = 0; i < kids.length; ) {
		const next = users.find((j) => j > i);
		// collapse finished turns: a newer prompt exists, or the agent is idle
		if (kids[i] instanceof UserMessageComponent && (next !== undefined || !busy)) {
			const end = next ?? kids.length;
			shown.push(...viewTurn(kids.slice(i, end)));
			i = end;
		} else shown.push(kids[i++]);
	}
	const lines: string[] = [];
	const mouse: { component: any; height: number }[] = [];
	for (const c of shown) {
		const l = c.render(width);
		mouse.push({ component: c, height: l.length });
		lines.push(...l);
	}
	this.mouseLayout = { width, children: mouse }; // Container.handleMouse routes clicks by this
	return lines;
}

function findChat(n: any, seen = new Set<any>()): any {
	if (!n || typeof n !== "object" || seen.has(n)) return;
	seen.add(n);
	if (Array.isArray(n.children) && n.children.some((c: any) => c instanceof UserMessageComponent)) return n;
	const next = [n.child, ...(n.entries ?? []).map((e: any) => e.component), ...(n.children ?? [])];
	for (const c of next) {
		const r = findChat(c, seen);
		if (r) return r;
	}
}

function attach(ctx: ExtensionContext) {
	if (ctx.mode !== "tui") return;
	ctx.ui.setWidget("turn-collapse-probe", (t, th) => {
		tui = t;
		theme = th;
		return { render: () => [], invalidate() {} };
	});
	ctx.ui.setWidget("turn-collapse-probe", undefined);
	if (typeof tui?.setLayoutRoot !== "function") return; // regular mode: scrollback can't be re-rendered
	const chat = findChat(tui.layoutRoot);
	if (!chat || chat[PATCH] === TOKEN) return;
	chat[PATCH] = TOKEN;
	chat.render = render;
	const inv = Object.getPrototypeOf(chat).invalidate;
	chat.invalidate = function () {
		clones = new WeakMap(); // theme change → rebuild reply clones
		inv.call(this);
	};
	tui.requestRender();
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_e, ctx) => {
		allExpanded = false;
		flipped = new WeakSet();
		attach(ctx);
		setTimeout(() => attach(ctx), 300); // ponytail: resumed history may render after session_start
	});
	pi.on("turn_start", (_e, ctx) => attach(ctx));
	pi.on("agent_start", (_e, ctx) => {
		busy = true;
		attach(ctx);
	});
	pi.on("agent_end", () => {
		busy = false;
		tui?.requestRender();
	});

	pi.registerShortcut("alt+o", {
		description: "Expand / collapse all past turns",
		handler: (ctx) => {
			attach(ctx);
			allExpanded = !allExpanded;
			flipped = new WeakSet();
			tui?.requestRender();
		},
	});
}
