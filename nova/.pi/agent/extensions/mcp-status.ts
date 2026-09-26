/**
 * Rewrites pi-mcp-adapter's footer status
 * "🔌 MCP: 2 servers enabled (1 connected)" -> "🔌 MCP: 2 (1)".
 * ponytail: regex over the adapter's text; breaks silently if it rewords its status.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PATCHED = Symbol.for("mcp-status-patched");
const shorten = (t: string) =>
	t.replace(/(\d+) servers? enabled(?: \((\d+) connected\))?/, (_m, n, c) => `${n} (${c ?? 0})`);

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_e, ctx) => {
		const ui = ctx.ui as typeof ctx.ui & { [PATCHED]?: true };
		if (ui[PATCHED]) return;
		const orig = ui.setStatus.bind(ui);
		ui.setStatus = (key, text) => orig(key, key === "mcp" && text ? shorten(text) : text);
		ui[PATCHED] = true;
	});
}
