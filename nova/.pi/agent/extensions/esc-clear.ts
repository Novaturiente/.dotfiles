/**
 * Claude Code style: Esc twice (within 500ms) with text in the editor clears it.
 * Skipped while the agent is streaming so Esc still aborts.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { matchesKey } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
	let unsub: (() => void) | undefined;

	pi.on("session_start", (_e, ctx) => {
		unsub?.();
		let last = 0;
		unsub = ctx.ui.onTerminalInput((data) => {
			if (!matchesKey(data, "escape") || !ctx.isIdle() || !ctx.ui.getEditorText().trim()) {
				last = 0;
				return;
			}
			const now = Date.now();
			if (now - last < 500) {
				ctx.ui.setEditorText("");
				last = 0;
				return { consume: true };
			}
			last = now;
		});
	});

	pi.on("session_shutdown", () => {
		unsub?.();
		unsub = undefined;
	});
}
