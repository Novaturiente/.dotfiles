/**
 * Git file tree as the "Files" tab of the pi side panel (../panel). Opens only by hand:
 * /files shows or hides it.
 * The swarm panel outranks it: while subagents show, the tree waits in the background
 * (folds kept) and comes back when the swarm tab closes.
 */
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import * as panel from "../panel/lib.mjs";

const TREE = fileURLToPath(new URL("./tree.mjs", import.meta.url));

export default function (pi: ExtensionAPI) {
	// Subagents run in hidden windows; the tree belongs to the pi pane the user sees.
	if (process.env.PI_SWARM_ID || !panel.panelDir()) return;
	const open = () => panel.openTab("files", { title: "Files", priority: 10, cmd: [process.execPath, TREE], width: "22%" });

	pi.registerCommand("files", {
		description: "Show or hide the git file tree panel",
		handler: async () => {
			const shown = panel.visibleTab()?.name === "files";
			if (shown) return panel.closeTab("files");
			if (panel.tab("files")) panel.showTab("files");
			else {
				open();
				panel.showTab("files"); // asked for by hand: show even over a higher-priority tab
			}
		},
	});

	pi.on("session_shutdown", (e) => {
		if (e.reason === "quit") panel.closeTab("files");
	});
}
