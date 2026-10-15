#!/usr/bin/env node
// For TUIs running in a tab (e.g. tree.py): `cli.mjs cycle` | `cli.mjs close <tab>`.
// Needs PI_PANEL_DIR / PI_PANEL_OWNER, which every tab pane gets from openTab().
import { closeTab, cycle } from "./lib.mjs";

const [cmd, name] = process.argv.slice(2);
if (cmd === "cycle") cycle();
else if (cmd === "close" && name) closeTab(name);
else {
	console.error("usage: cli.mjs cycle | close <tab>");
	process.exit(1);
}
