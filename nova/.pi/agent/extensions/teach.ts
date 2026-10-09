/**
 * teach — session-long learning mode.
 *
 *   /teach          turn on (or report status if already on)
 *   /teach off      turn off   (also: saying "stop teaching")
 *   /teach status   report state
 *
 * While on: injects ~/.pi/agent/skills/teach/SKILL.md into the system prompt every
 * turn (survives compaction) and blocks write/edit so the learner types the code.
 * Progress is kept in <cwd>/.teach/progress.md (git-excluded locally) so learning
 * can stop and resume across sessions.
 */
import { execFileSync } from "node:child_process";
import { appendFileSync, existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve, sep } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SKILL_PATH = join(homedir(), ".pi", "agent", "skills", "teach", "SKILL.md");
const ENTRY = "teach-mode";
const STOP_PHRASE = /^\s*stop teaching[.!\s]*$/i;
// Lesson pages are the one place the agent may write while teaching.
const LESSONS = "/tmp/teach-lessons";

// Progress tracking lives in the project, so each project resumes independently.
const progressDir = (cwd: string) => join(cwd, ".teach");

function isAllowedPath(p: unknown, cwd: string): boolean {
	if (typeof p !== "string" || !p) return false;
	const abs = resolve(cwd, p.replace(/^~(?=\/)/, homedir()));
	return abs.startsWith(LESSONS + sep) || abs.startsWith(progressDir(cwd) + sep);
}

// Keep .teach/ out of commits without touching the project's .gitignore.
function excludeFromGit(cwd: string) {
	try {
		const rel = execFileSync("git", ["rev-parse", "--git-path", "info/exclude"], {
			cwd,
			encoding: "utf8",
			stdio: ["ignore", "pipe", "ignore"],
		}).trim();
		const file = resolve(cwd, rel);
		const text = existsSync(file) ? readFileSync(file, "utf8") : "";
		if (!/^\/?\.teach\/?$/m.test(text)) appendFileSync(file, (text && !text.endsWith("\n") ? "\n" : "") + ".teach/\n");
	} catch {
		// Not a git repo (or no git): nothing to exclude.
	}
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
		description: "Teach mode: guide, don't write code. Args: off | status | review",
		handler: async (args, ctx) => {
			const arg = String(args ?? "").trim().toLowerCase();
			if (arg === "status" || (!arg && on)) {
				ctx.ui.notify(`Teach mode is ${on ? "on" : "off"}.`, "info");
				return;
			}
			if (arg === "off" || arg === "stop") return set(false, ctx);
			if (!arg || arg === "on") {
				excludeFromGit(ctx?.cwd ?? process.cwd());
				return set(true, ctx);
			}
			if (arg === "review") {
				if (!on) {
					excludeFromGit(ctx?.cwd ?? process.cwd());
					set(true, ctx);
				}
				// Same phrase the skill recognises in other harnesses.
				return pi.sendUserMessage("Review session: quiz me only on concepts that are due for review.");
			}
			ctx.ui.notify(`Unknown: "${arg}". Use /teach, /teach off, /teach status, /teach review.`, "warning");
		},
	});

	pi.on("input", async (event, ctx) => {
		if (on && event.source !== "extension" && STOP_PHRASE.test(event.text)) set(false, ctx);
		return { action: "continue" };
	});

	pi.on("before_agent_start", async (event, ctx) => {
		const sections = event.systemPromptOptions.sections;
		if (!on) {
			delete sections.teach;
			return;
		}
		const dir = progressDir(ctx?.cwd ?? process.cwd());
		const state = (f: string) => `${join(dir, f)} (${existsSync(join(dir, f)) ? "exists" : "not created yet"})`;
		sections.teach =
			"TEACH MODE IS ON. It overrides CAVEMAN MODE (write full plain sentences) and ponytail's " +
			"instruction to write code. Follow these rules for every reply until the user turns it off:\n\n" +
			skillBody() +
			`\n\nSkill folder (for references/, scripts/, assets/): ${dirname(SKILL_PATH)}. ` +
			`.teach/ is already git-excluded. Brief: ${state("brief.md")}. Progress: ${state("progress.md")}.`;
	});

	pi.on("tool_call", async (event, ctx) => {
		if (!on || (event.toolName !== "write" && event.toolName !== "edit")) return;
		if (isAllowedPath((event.input as { path?: unknown })?.path, ctx?.cwd ?? process.cwd())) return;
		return {
			block: true,
			reason:
				"Teach mode is on: do not write the learner's files (only /tmp/teach-lessons/ and the project's .teach/ are allowed). " +
				"Show it in chat and have the learner do it themselves. " +
				"The learner can run /teach off to let you edit files.",
		};
	});
}
