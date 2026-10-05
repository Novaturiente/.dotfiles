/**
 * Reports Pi's state to the tmux agent sidebar via ~/.config/tmux/agent-state.sh.
 * working = turn running, blocked = waiting on an ask-user answer, idle = settled.
 */
import { execFile, execFileSync } from "node:child_process";
import { homedir } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SCRIPT = `${homedir()}/.config/tmux/agent-state.sh`;

export default function (pi: ExtensionAPI) {
	if (!process.env.TMUX_PANE) return;

	let root = false;
	let active = false;
	let blocked = 0;
	let last = "";
	let queue = Promise.resolve();

	const publish = () => {
		const state = blocked > 0 ? "blocked" : active ? "working" : "idle";
		if (state === last) return;
		last = state;
		// Serialized so a fast working->idle never lands out of order.
		queue = queue.then(
			() => new Promise<void>((done) => execFile(SCRIPT, ["pi", state], () => done())),
		);
	};

	pi.events.on("rpiv:ask-user:blocked", (data: { active?: boolean }) => {
		if (!root) return;
		blocked = data?.active ? blocked + 1 : Math.max(0, blocked - 1);
		publish();
	});

	pi.on("session_start", (_e, ctx) => {
		// TUI only: subagents/print/RPC modes have no pane of their own.
		if (ctx?.mode !== "tui") return;
		root = true;
		active = ctx?.isIdle?.() === false;
		publish();
	});

	pi.on("agent_start", () => {
		if (!root) return;
		active = true;
		publish();
	});

	pi.on("agent_settled", (_e, ctx) => {
		if (!root || ctx?.isIdle?.() !== true) return;
		active = false;
		publish();
	});

	pi.on("session_shutdown", () => {
		if (!root) return;
		try {
			execFileSync(SCRIPT, ["pi", "off"]);
		} catch {
			// tmux server already gone on shutdown: nothing left to clear.
		}
	});
}
