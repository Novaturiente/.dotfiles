#!/usr/bin/env node
// Panel actions: ctl.mjs <open|read|stop|resume> <root> <id>
import fs from "node:fs";
import path from "node:path";
import { agentDir, launch, livePanes, record, stop, tmux, toggleOpen } from "./core.mjs";

const [cmd, root, id] = process.argv.slice(2);
const r = root && id ? record(root, id) : undefined;
if (!r) {
	console.error(`unknown agent ${id}`);
	process.exit(1);
}
try {
	if (cmd === "open") toggleOpen(root, id);
	else if (cmd === "stop") stop(root, id);
	else if (cmd === "read") {
		const file = path.join(agentDir(root, id), "result.md");
		if (!fs.existsSync(file)) throw new Error(`${id} has no result yet`);
		tmux("display-popup", "-E", "-w", "85%", "-h", "85%", "-T", ` ${id} result `, "less", "-R", file);
	} else if (cmd === "resume") {
		if (r.ctl.pane && livePanes().has(r.ctl.pane)) throw new Error(`${id} is still running; open it instead`);
		launch(root, id, { resume: true });
	} else throw new Error(`unknown command ${cmd}`);
} catch (e) {
	console.error(e.message);
	process.exit(1);
}
