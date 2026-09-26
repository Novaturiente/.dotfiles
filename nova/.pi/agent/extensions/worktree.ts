/**
 * Claude Code-style worktrees for pi.
 *
 * Tools `enter_worktree` / `exit_worktree` (model-callable) hand off to the
 * `/wt-enter` / `/wt-exit` commands, because only commands may call
 * ctx.switchSession(). The command waits for the turn to end, forks the
 * conversation into a session whose cwd is the target checkout, switches to it,
 * and (when a tool triggered it) tells the agent to continue.
 *
 * Worktrees: <repo>/.claude/worktrees/<name> on branch worktree-<name>
 * (same layout as Claude Code). Untracked root .env* files are copied in.
 *
 * Also prints `cd <cwd> && pi --session <id>` on quit (TUI mode only).
 */
import { execFile, execFileSync } from "node:child_process";
import { appendFileSync, copyFileSync, existsSync, mkdirSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { promisify } from "node:util";
import { Type } from "@earendil-works/pi-ai";
import { type ExtensionAPI, type ExtensionCommandContext, SessionManager } from "@earendil-works/pi-coding-agent";

const run = promisify(execFile);
const NAME = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;

const git = async (cwd: string, ...args: string[]) =>
	(await run("git", args, { cwd, maxBuffer: 16 << 20 })).stdout.trim();
const gitOk = (cwd: string, ...args: string[]) => git(cwd, ...args).then(() => true, () => false);
const errText = (e: unknown) => ((e as { stderr?: string }).stderr?.trim() || (e as Error).message);
const shq = (s: string) => (/^[\w@%+=:,./-]+$/.test(s) ? s : `'${s.replace(/'/g, "'\\''")}'`);

async function repoInfo(cwd: string) {
	const [top, gitDir, common] = (
		await git(cwd, "rev-parse", "--path-format=absolute", "--show-toplevel", "--git-dir", "--git-common-dir")
	).split("\n");
	const worktrees = (await git(cwd, "worktree", "list", "--porcelain"))
		.split("\n")
		.filter((l) => l.startsWith("worktree "))
		.map((l) => l.slice(9));
	return { top, common, linked: gitDir !== common, main: worktrees[0], worktrees };
}

/** Create (or find) .claude/worktrees/<name>. Idempotent. */
async function prepare(cwd: string, name: string, base?: string) {
	if (!NAME.test(name)) throw new Error(`Invalid worktree name "${name}" (letters, digits, . _ - only).`);
	const info = await repoInfo(cwd);
	if (info.linked) throw new Error(`Already inside worktree ${info.top}. Call exit_worktree first.`);
	const path = join(info.top, ".claude", "worktrees", name);
	if (info.worktrees.includes(path)) {
		return { path, branch: await git(path, "branch", "--show-current"), created: false, copied: [] as string[] };
	}
	if (existsSync(path)) throw new Error(`${path} exists but is not a registered git worktree.`);

	if (!(await gitOk(info.top, "check-ignore", "-q", ".claude/worktrees/x"))) {
		mkdirSync(join(info.common, "info"), { recursive: true });
		appendFileSync(join(info.common, "info", "exclude"), "\n.claude/worktrees/\n");
	}
	const branch = `worktree-${name}`;
	const exists = await gitOk(info.top, "show-ref", "--verify", "-q", `refs/heads/${branch}`);
	try {
		await git(info.top, ...(exists
			? ["worktree", "add", path, branch]
			: ["worktree", "add", "-b", branch, path, base ?? "HEAD"]));
	} catch (e) {
		throw new Error(`git worktree add failed: ${errText(e)}`);
	}
	// ponytail: root-level .env* only; nested monorepo env files not copied
	const copied: string[] = [];
	for (const f of readdirSync(info.top, { withFileTypes: true })) {
		if (f.isFile() && f.name.startsWith(".env") && !existsSync(join(path, f.name))) {
			copyFileSync(join(info.top, f.name), join(path, f.name));
			copied.push(f.name);
		}
	}
	return { path, branch, created: true, copied };
}

export default function (pi: ExtensionAPI) {
	let autoContinue = false; // set by a tool, consumed by the command it queues

	// Footer path (powerline custom item "wtpath"): <root>:<worktree> inside a worktree, else basename.
	pi.on("session_start", (_e, ctx) => {
		const m = ctx.cwd.match(/\/([^/]+)\/\.claude\/worktrees\/([^/]+)$/);
		ctx.ui.setStatus("wtpath", m ? `${m[1]}:${m[2]}` : ctx.cwd.split("/").pop() || ctx.cwd);
	});

	/** Fork the conversation into a session rooted at `target` and switch to it. */
	async function switchInto(
		ctx: ExtensionCommandContext,
		target: string,
		note: string,
		after?: () => Promise<string>,
	) {
		await ctx.waitForIdle();
		const src = ctx.sessionManager.getSessionFile();
		let file = src && existsSync(src) ? SessionManager.forkFrom(src, target).getSessionFile() : undefined;
		if (!file || !existsSync(file)) {
			// forkFrom defers writing until an assistant reply exists; switchSession needs a file on disk.
			const sm = SessionManager.create(target);
			file = sm.getSessionFile()!;
			const lines = [sm.getHeader(), ...ctx.sessionManager.getBranch()].map((e) => JSON.stringify(e));
			writeFileSync(file, `${lines.join("\n")}\n`, { flag: "wx", mode: 0o600 });
		}
		const auto = autoContinue;
		autoContinue = false;
		const res = await ctx.switchSession(file, {
			withSession: async (c) => {
				const msg = note + (after ? await after() : "");
				c.ui.notify(msg, "info");
				if (auto) c.sendUserMessage(`${msg} Continue the task.`).catch(() => {});
			},
		});
		if (res.cancelled) ctx.ui.notify("Worktree switch was cancelled.", "warning");
	}

	pi.registerCommand("wt-enter", {
		description: "Create or enter .claude/worktrees/<name> and move this session into it: /wt-enter <name> [base]",
		handler: async (args, ctx) => {
			const [name, base] = args.trim().split(/\s+/);
			try {
				if (!name) throw new Error("Usage: /wt-enter <name> [base]");
				const wt = await prepare(ctx.cwd, name, base);
				const copied = wt.copied.length ? ` Copied ${wt.copied.join(", ")}.` : "";
				await switchInto(ctx, wt.path, `Now working in worktree ${wt.path} on branch ${wt.branch}.${copied} All tools run there.`);
			} catch (e) {
				autoContinue = false;
				ctx.ui.notify(errText(e), "error");
			}
		},
	});

	pi.registerCommand("wt-exit", {
		description: "Leave the current worktree (keep or remove it) and move this session back to the main checkout",
		handler: async (_args, ctx) => {
			try {
				const info = await repoInfo(ctx.cwd);
				if (!info.linked) throw new Error("Not inside a linked worktree.");
				await ctx.waitForIdle();
				const branch = await git(info.top, "branch", "--show-current");
				const dirty = (await git(info.top, "status", "--porcelain")).split("\n").filter(Boolean).length;
				const mainHead = await git(info.main, "rev-parse", "HEAD");
				const ahead = await git(info.top, "rev-list", "--count", `${mainHead}..HEAD`);

				let choice = "Keep worktree";
				if (ctx.hasUI) {
					const picked = await ctx.ui.select(
						`Leave ${info.top} (${branch || "detached"}): ${dirty} uncommitted file(s), ${ahead} commit(s) not in main checkout`,
						["Keep worktree", "Remove worktree"],
					);
					if (!picked) {
						autoContinue = false;
						ctx.ui.notify("Worktree exit cancelled; still in the worktree.", "info");
						return;
					}
					choice = picked;
				}
				const top = info.top;
				const main = info.main;
				const remove = choice === "Remove worktree"
					? async () => {
							try {
								await git(main, "worktree", "remove", top);
							} catch (e) {
								return ` Worktree NOT removed: ${errText(e)}`;
							}
							if (!branch) return " Worktree removed.";
							return (await gitOk(main, "branch", "-d", branch))
								? ` Worktree and branch ${branch} removed.`
								: ` Worktree removed; branch ${branch} kept (not merged).`;
						}
					: undefined;
				await switchInto(
					ctx,
					main,
					`Back in main checkout ${main}.${remove ? "" : ` Worktree kept at ${top} (branch ${branch}).`}`,
					remove,
				);
			} catch (e) {
				autoContinue = false;
				ctx.ui.notify(errText(e), "error");
			}
		},
	});

	pi.registerTool({
		name: "enter_worktree",
		label: "Enter worktree",
		description:
			"Create (or reuse) an isolated git worktree at <repo>/.claude/worktrees/<name> on branch worktree-<name> and move this session into it. " +
			"Use before editing files in a project checkout. The switch happens when this turn ends; the conversation carries over and you continue in the worktree. " +
			"Call it alone, not alongside other tools.",
		parameters: Type.Object({
			name: Type.String({ description: "Short kebab-case worktree name, e.g. fix-login-redirect" }),
			base: Type.Optional(Type.String({ description: "Commit or branch to start a new branch from (default: current HEAD)" })),
		}),
		async execute(_id, params, _signal, _onUpdate, ctx) {
			const wt = await prepare(ctx.cwd, params.name, params.base);
			autoContinue = true;
			pi.sendUserMessage(`/wt-enter ${params.name}`, { expandPromptTemplates: true });
			return {
				content: [{
					type: "text",
					text: `Worktree ${wt.path} (branch ${wt.branch}) ${wt.created ? "created" : "already existed"}. ` +
						"The session switches into it when this turn ends. Stop now; you will be prompted to continue there.",
				}],
				details: wt,
				terminate: true,
			};
		},
	});

	pi.registerTool({
		name: "exit_worktree",
		label: "Exit worktree",
		description:
			"Leave the current git worktree and move this session back to the main checkout. The user is asked whether to keep or remove the worktree " +
			"(removal refuses uncommitted changes and keeps unmerged branches). Call it alone, after committing the work.",
		parameters: Type.Object({}),
		async execute(_id, _params, _signal, _onUpdate, ctx) {
			const info = await repoInfo(ctx.cwd);
			if (!info.linked) throw new Error("Not inside a linked worktree.");
			autoContinue = true;
			pi.sendUserMessage("/wt-exit", { expandPromptTemplates: true });
			return {
				content: [{ type: "text", text: `Leaving ${info.top} when this turn ends. Stop now.` }],
				details: { from: info.top, to: info.main },
				terminate: true,
			};
		},
	});

	let hooked = false;
	let hint = "";
	pi.on("session_shutdown", (event, ctx) => {
		if (event.reason !== "quit" || ctx.mode !== "tui") return;
		const file = ctx.sessionManager.getSessionFile();
		if (!file || !existsSync(file)) return;
		const wt = ctx.cwd.match(/\/\.claude\/worktrees\/([^/]+)$/)?.[1];
		let label = "";
		if (wt) {
			let branch = "";
			try {
				branch = execFileSync("git", ["branch", "--show-current"], { cwd: ctx.cwd, encoding: "utf8" }).trim();
			} catch {}
			label = ` in worktree ${wt}${branch ? ` (branch ${branch})` : ""}`;
		}
		hint = `Resume this session${label}:\n  cd ${shq(ctx.cwd)} && pi --session ${ctx.sessionManager.getSessionId()}`;
		if (hooked) return;
		hooked = true;
		// "exit" runs after pi restores the terminal, so the line is not wiped.
		process.once("exit", () => process.stderr.write(`\n${hint}\n`));
	});
}
