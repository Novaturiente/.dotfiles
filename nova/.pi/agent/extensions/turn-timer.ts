/**
 * Footer statuses: current-turn elapsed time + running subagent count.
 * Session elapsed is powerline's `time_spent` segment, not here.
 */
import type {
	ExtensionAPI,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const SUBAGENT_TOOLS = new Set(["subagent", "task"]);

const fmt = (ms: number) => {
	const s = Math.floor(ms / 1000);
	return s < 60
		? `${s}s`
		: `${Math.floor(s / 60)}m${String(s % 60).padStart(2, "0")}s`;
};

export default function (pi: ExtensionAPI) {
	let started = 0;
	let timer: ReturnType<typeof setInterval> | null = null;
	const running = new Map<string, number>(); // toolCallId -> start ms

	const paint = (ctx: Pick<ExtensionContext, "ui">) => {
		const t = ctx.ui.theme;
		ctx.ui.setStatus(
			"turn",
			started
				? t.fg("accent", "turn ") + t.fg("text", fmt(Date.now() - started))
				: "",
		);
		if (running.size === 0) {
			ctx.ui.setStatus("subagent", "");
			return;
		}
		const oldest = Math.min(...running.values());
		ctx.ui.setStatus(
			"subagent",
			t.fg("accent", `⚙ ${running.size} subagent${running.size > 1 ? "s" : ""} `) +
				t.fg("text", fmt(Date.now() - oldest)),
		);
	};

	const tick = (ctx: Pick<ExtensionContext, "ui">) => {
		if (timer) return;
		timer = setInterval(() => paint(ctx), 1000);
	};
	const stop = () => {
		if (timer) clearInterval(timer);
		timer = null;
	};

	pi.on("agent_start", (_e, ctx) => {
		started = Date.now();
		paint(ctx);
		tick(ctx);
	});

	pi.on("agent_settled", (_e, ctx) => {
		stop();
		paint(ctx); // freeze final duration
	});

	pi.on("tool_call", (event, ctx) => {
		if (SUBAGENT_TOOLS.has(event.toolName)) {
			running.set(event.toolCallId, Date.now());
			paint(ctx);
		}
	});

	pi.on("tool_result", (event, ctx) => {
		if (running.delete(event.toolCallId)) paint(ctx);
	});

	pi.on("session_shutdown", () => {
		stop();
		running.clear();
	});
}
