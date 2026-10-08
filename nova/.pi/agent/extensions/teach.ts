/**
 * teach — session-long learning mode.
 *
 *   /teach          turn on (or report status if already on)
 *   /teach off      turn off   (also: saying "stop teaching")
 *   /teach status   report state
 *
 * While on: injects ~/.pi/agent/skills/teach/SKILL.md into the system prompt every
 * turn (survives compaction) and blocks write/edit so the learner types the code.
 */
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve, sep } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SKILL_PATH = join(homedir(), ".pi", "agent", "skills", "teach", "SKILL.md");
const ENTRY = "teach-mode";
const STOP_PHRASE = /^\s*stop teaching[.!\s]*$/i;
// Lesson pages are the one place the agent may write while teaching.
const LESSONS = "/tmp/teach-lessons";

function isLessonPath(p: unknown, cwd: string): boolean {
	if (typeof p !== "string" || !p) return false;
	const abs = resolve(cwd, p.replace(/^~(?=\/)/, homedir()));
	return abs.startsWith(LESSONS + sep);
}

function skillBody(): string {
	// Read every turn so edits to SKILL.md apply without /reload.
	return readFileSync(SKILL_PATH, "utf8").replace(/^---\n[\s\S]*?\n---\n/, "").trim();
}

export default function teach(pi: ExtensionAPI) {
	let on = false;

	const sync = (ctx: any) => ctx?.ui?.setStatus?.("teach", on ? "🎓 teach" : undefined);

	const set = (value: boolean, ctx: any) => {
		on = value;
		pi.appendEntry(ENTRY, { on });
		sync(ctx);
		ctx?.ui?.notify?.(on ? "Teach mode on. /teach off to stop." : "Teach mode off.", "info");
	};

	const restore = (ctx: any) => {
		const entries = ctx?.sessionManager?.getBranch?.() ?? [];
		on = false;
		for (const e of entries) {
			if (e?.type === "custom" && e?.customType === ENTRY) on = Boolean(e.data?.on);
		}
		sync(ctx);
	};

	pi.on("session_start", async (_e, ctx) => restore(ctx));
	pi.on("session_tree", async (_e, ctx) => restore(ctx));

	pi.registerCommand("teach", {
		description: "Teach mode: guide, don't write code. Args: off | status",
		handler: async (args, ctx) => {
			const arg = String(args ?? "").trim().toLowerCase();
			if (arg === "status" || (!arg && on)) {
				ctx.ui.notify(`Teach mode is ${on ? "on" : "off"}.`, "info");
				return;
			}
			if (arg === "off" || arg === "stop") return set(false, ctx);
			if (!arg || arg === "on") return set(true, ctx);
			ctx.ui.notify(`Unknown: "${arg}". Use /teach, /teach off, /teach status.`, "warning");
		},
	});

	pi.on("input", async (event, ctx) => {
		if (on && event.source !== "extension" && STOP_PHRASE.test(event.text)) set(false, ctx);
		return { action: "continue" };
	});

	pi.on("before_agent_start", async (event) => {
		const sections = event.systemPromptOptions.sections;
		if (!on) {
			delete sections.teach;
			return;
		}
		sections.teach =
			"TEACH MODE IS ON. It overrides CAVEMAN MODE (write full plain sentences) and ponytail's " +
			"instruction to write code. Follow these rules for every reply until the user turns it off:\n\n" +
			skillBody();
	});

	pi.on("tool_call", async (event, ctx) => {
		if (!on || (event.toolName !== "write" && event.toolName !== "edit")) return;
		if (isLessonPath((event.input as { path?: unknown })?.path, ctx?.cwd ?? process.cwd())) return;
		return {
			block: true,
			reason:
				"Teach mode is on: do not write the learner's files (only /tmp/teach-lessons/ is allowed). " +
				"Show the code in chat and have the learner type it. " +
				"The learner can run /teach off to let you edit files.",
		};
	});
}
