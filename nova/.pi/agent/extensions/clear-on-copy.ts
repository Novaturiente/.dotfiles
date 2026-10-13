/**
 * Fullscreen pi: drop the mouse selection highlight once it has been copied,
 * like tmux's copy-pipe-and-cancel. Runtime patch of pi-tui, so it survives pi updates
 * (no edit to node_modules to reapply).
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { TuiAltScreen } from "@earendil-works/pi-tui";

const P = TuiAltScreen.prototype as any;
if (!P.__clearOnCopy) {
	P.__clearOnCopy = true;
	const orig = P.copySelectionToClipboard;
	P.copySelectionToClipboard = async function (this: any) {
		const ok = await orig.call(this);
		if (ok) {
			this.clearTextSelection();
			this.requestRender();
		}
		return ok;
	};
}

export default function (_pi: ExtensionAPI) {}
