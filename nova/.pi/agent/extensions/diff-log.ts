/**
 * Append every edit/write diff to /tmp/pi-diffs/<session>.diff and point
 * /tmp/pi-diffs/latest.diff at it. View live in a side pane with `pi-diffs`.
 * Before a file's first edit in a session, snapshot it into <session>.d/ and
 * list it in <session>.d/files, so `pi-review` (Emacs) can diff original vs current.
 */
import { appendFileSync, copyFileSync, existsSync, mkdirSync, readFileSync, renameSync, symlinkSync } from "node:fs";
import { resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const DIR = "/tmp/pi-diffs";

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", (event, ctx) => {
		if (event.toolName !== "edit" && event.toolName !== "write") return;
		const abs = resolve(ctx.cwd, String(event.input.path ?? ""));
		const dir = `${DIR}/${ctx.sessionManager.getSessionId()}.d`;
		const manifest = `${dir}/files`;
		mkdirSync(dir, { recursive: true });
		if (existsSync(manifest) && readFileSync(manifest, "utf8").includes(`${abs}\t`)) return;
		let snap = "NEW";
		if (existsSync(abs)) {
			snap = `${dir}/${abs.replaceAll("/", "%")}`;
			copyFileSync(abs, snap);
		}
		appendFileSync(manifest, `${abs}\t${snap}\n`);
	});

	pi.on("tool_result", (event, ctx) => {
		if (event.isError) return;
		const path = String(event.input.path ?? "");
		let text: string;
		if (event.toolName === "edit") {
			const patch = (event.details as { patch?: string } | undefined)?.patch;
			if (!patch) return;
			text = patch;
		} else if (event.toolName === "write") {
			// ponytail: write has no patch in details; log a summary, full diff lives in pi-review
			const lines = String(event.input.content ?? "").replace(/\n$/, "").split("\n").length;
			text = `=== write ${path} (${lines} lines)\n`;
		} else return;

		mkdirSync(DIR, { recursive: true });
		const file = `${DIR}/${ctx.sessionManager.getSessionId()}.diff`;
		const stamp = new Date().toLocaleTimeString("en-IN", { timeZone: "Asia/Kolkata", hour12: false });
		appendFileSync(file, `\n### ${stamp} IST  ${event.toolName}  ${path}\n${text.endsWith("\n") ? text : text + "\n"}`);
		// atomic symlink swap so `tail -F latest.diff` follows the active session
		const tmp = `${DIR}/.latest.${process.pid}`;
		symlinkSync(file, tmp);
		renameSync(tmp, `${DIR}/latest.diff`);
	});
}
