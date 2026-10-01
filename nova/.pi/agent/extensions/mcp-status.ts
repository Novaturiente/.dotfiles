/**
 * Footer status "🔌 MCP: <servers> (<connected>)" for pi's built-in MCP.
 * Built-in MCP exposes no connection state to extensions, so "connected" =
 * server has registered tools (tools only appear after connect).
 * ponytail: polls getAllTools every 2s until all connected; a later drop isn't shown
 * (tools stay registered). Switch to a real event if pi ever exposes one.
 * ponytail: counts only extension-registered servers (project-mcp.ts); add mcp.json
 * servers if you ever start using it.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ns = (server: string) => `mcp__${server.replace(/-/g, "_")}`;

export default function (pi: ExtensionAPI) {
	let timer: ReturnType<typeof setInterval> | undefined;
	const stop = () => {
		clearInterval(timer);
		timer = undefined;
	};

	pi.on("session_start", (_e, ctx) => {
		stop();
		const update = () => {
			const names = pi.getMcpServers().map((s) => ns(s.name));
			const live = new Set(
				pi.getAllTools().flatMap((t) => (t.exposure !== "hidden" && t.namespace ? [t.namespace.name] : [])),
			);
			const up = names.filter((n) => live.has(n)).length;
			ctx.ui.setStatus("mcp", names.length ? `🔌 MCP: ${names.length} (${up})` : undefined);
			if (up === names.length) stop();
		};
		update();
		if (!timer) timer = setInterval(update, 2000);
	});
	pi.on("session_shutdown", stop);
}
