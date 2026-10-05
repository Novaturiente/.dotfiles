// Rewind: one checkpoint per user prompt, stored as session entries (branch-aware).
// Git repo: whole worktree snapshot (catches bash). Non-git: only files touched by edit/write (pre-images).
import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, promises as fs } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { isAbsolute, join, relative, resolve } from "node:path";
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

interface Repo { root: string; shadow?: string }
const CP = "rewind-cp";
const PATCH = "rewind-patch";

function git(repo: Repo, args: string[], env: NodeJS.ProcessEnv = {}): Promise<{ ok: boolean; out: string }> {
	const base = repo.shadow ? ["--git-dir", repo.shadow, "--work-tree", repo.root] : ["-C", repo.root];
	return new Promise((res) =>
		execFile("git", [...base, ...args], { encoding: "utf8", maxBuffer: 64 << 20, env: { ...process.env, ...env } },
			(err, out) => res({ ok: !err, out: String(out || "") })),
	);
}

async function resolveRepo(cwd: string): Promise<Repo> {
	const top = await new Promise<string>((res) =>
		execFile("git", ["-C", cwd, "rev-parse", "--show-toplevel"], { encoding: "utf8" }, (e, o) => res(e ? "" : String(o).trim())));
	if (top) return { root: top };
	const dir = join(homedir(), ".pi/agent/shadow-git", createHash("sha1").update(cwd).digest("hex").slice(0, 16));
	if (!existsSync(join(dir, "HEAD"))) {
		mkdirSync(dir, { recursive: true });
		await new Promise<void>((res) => execFile("git", ["init", "--bare", "-q", dir], () => res()));
	}
	return { root: cwd, shadow: dir };
}

async function withIndex<T>(fn: (env: NodeJS.ProcessEnv) => Promise<T>): Promise<T> {
	const idx = join(tmpdir(), `pi-rewind-${Date.now()}-${Math.random().toString(36).slice(2)}.idx`);
	try { return await fn({ GIT_INDEX_FILE: idx }); } finally { await fs.unlink(idx).catch(() => {}); }
}

// Snapshot worktree into a tree sha. Non-git: only `paths`.
function snapshot(repo: Repo, paths: string[]): Promise<string | undefined> {
	return withIndex(async (env) => {
		if (repo.shadow) {
			const have = paths.filter((p) => existsSync(join(repo.root, p)));
			if (have.length) await git(repo, ["add", "-A", "--", ...have], env);
		} else {
			// Seed from real index so unchanged tracked files hit git's stat cache instead of being re-hashed.
			const idx = (await git(repo, ["rev-parse", "--git-path", "index"])).out.trim();
			if (idx) await fs.copyFile(resolve(repo.root, idx), env.GIT_INDEX_FILE!).catch(() => {});
			await git(repo, ["add", "-u"], env);
			// ponytail: untracked files > 256KB skipped (multi-GB exports made every prompt hang); rewind won't restore those.
			const u = await git(repo, ["ls-files", "-z", "-o", "--exclude-standard"], env);
			const all = u.out.split("\0").filter(Boolean);
			const sizes = await Promise.all(all.map((p) => fs.stat(join(repo.root, p)).then((s) => s.size, () => Infinity)));
			const small = all.filter((_, i) => sizes[i] <= 256 << 10);
			for (let i = 0; i < small.length; i += 200) await git(repo, ["add", "--", ...small.slice(i, i + 200)], env);
		}
		const t = await git(repo, ["write-tree"], env);
		return t.ok ? t.out.trim() : undefined;
	});
}

function withPatches(repo: Repo, tree: string, patches: Map<string, string | null>): Promise<string | undefined> {
	return withIndex(async (env) => {
		await git(repo, ["read-tree", tree], env);
		for (const [p, blob] of patches) {
			if (blob) await git(repo, ["update-index", "--add", "--cacheinfo", `100644,${blob},${p}`], env);
			else await git(repo, ["update-index", "--force-remove", "--", p], env);
		}
		const t = await git(repo, ["write-tree"], env);
		return t.ok ? t.out.trim() : undefined;
	});
}

// Make worktree match `target`. Returns tree of the state before (for undo).
async function applyTree(repo: Repo, target: string, tracked: string[]): Promise<string | undefined> {
	const cur = await snapshot(repo, tracked);
	if (!cur) return undefined;
	const d = await git(repo, ["diff-tree", "-r", "-z", "--name-status", "--no-renames", cur, target]);
	if (!d.ok) return undefined;
	const tok = d.out.split("\0").filter(Boolean);
	const co: string[] = [];
	for (let i = 0; i + 1 < tok.length; i += 2) {
		const [st, p] = [tok[i], tok[i + 1]];
		if (st === "D") await fs.unlink(join(repo.root, p)).catch(() => {});
		else co.push(p);
	}
	if (co.length) {
		await withIndex(async (env) => {
			await git(repo, ["read-tree", target], env);
			for (let i = 0; i < co.length; i += 200) await git(repo, ["checkout-index", "-f", "--", ...co.slice(i, i + 200)], env);
		});
	}
	return cur;
}

function promptText(content: unknown): string {
	const raw = typeof content === "string" ? content
		: Array.isArray(content) ? content.map((c: any) => (c?.type === "text" ? c.text : "")).join(" ") : "";
	return raw.replace(/\S*clipboard\S*\.(png|jpe?g|gif|webp)/gi, "").replace(/\s+/g, " ").trim();
}

const hhmm = (ts: string | number) =>
	new Date(ts).toLocaleTimeString("en-GB", { timeZone: "Asia/Kolkata", hour: "2-digit", minute: "2-digit", hour12: false });

export default function (pi: ExtensionAPI) {
	let repo: Repo | undefined;
	const undo: string[] = []; // in-memory, files only

	const trackedPaths = (branch: readonly any[]) => [
		...new Set(branch.filter((e) => e.type === "custom" && e.customType === PATCH).map((e) => e.data.path as string)),
	];

	pi.on("session_start", async (_e, ctx) => { repo = await resolveRepo(ctx.cwd); });

	// Snapshot runs in the background so the turn starts at once; every tool call waits for it, so no
	// tool can change files before the checkpoint is taken. `late` = entry lands after its user message.
	let pendingCp: Promise<void> = Promise.resolve();
	pi.on("before_agent_start", async (_e, ctx) => {
		const paths = trackedPaths(ctx.sessionManager.getBranch());
		pendingCp = (async () => {
			repo ??= await resolveRepo(ctx.cwd);
			const tree = await snapshot(repo, paths);
			if (tree) pi.appendEntry(CP, { tree, late: true });
		})().catch(() => {});
	});
	pi.on("agent_end", async () => { await pendingCp; });

	// Non-git: save pre-image the first time a path is touched by edit/write.
	pi.on("tool_call", async (event, ctx) => {
		await pendingCp;
		if (!repo?.shadow || (event.toolName !== "edit" && event.toolName !== "write")) return;
		const raw = (event.input as any)?.path ?? (event.input as any)?.file_path;
		if (typeof raw !== "string") return;
		const abs = isAbsolute(raw) ? raw : resolve(ctx.cwd, raw);
		const rel = relative(repo.root, abs);
		if (!rel || rel.startsWith("..")) return;
		if (trackedPaths(ctx.sessionManager.getBranch()).includes(rel)) return;
		let blob: string | null = null;
		if (existsSync(abs)) {
			const h = await git(repo, ["hash-object", "-w", "--", abs]);
			if (!h.ok) return;
			blob = h.out.trim();
		}
		pi.appendEntry(PATCH, { path: rel, blob });
	});

	// Shortcut ctx lacks navigateTree, so route through the command (extension commands run without a turn).
	pi.registerShortcut("alt+r", {
		description: "Rewind to an earlier prompt",
		handler: () => pi.sendUserMessage("/rewind", { expandPromptTemplates: true }),
	});

	pi.registerCommand("rewind", {
		description: "Rewind files and/or chat to an earlier user prompt",
		handler: async (_a: string, ctx: ExtensionCommandContext) => {
			repo ??= await resolveRepo(ctx.cwd);
			const branch = ctx.sessionManager.getBranch() as any[];
			const items: { user: any; cpIdx: number }[] = [];
			let pending = -1; // legacy checkpoint: written before its user message
			let lastUser: any; // user message still waiting for a late checkpoint
			branch.forEach((e, i) => {
				if (e.type === "custom" && e.customType === CP) {
					if (!e.data.late) pending = i;
					else if (lastUser) items.push({ user: lastUser, cpIdx: i });
					if (e.data.late) lastUser = undefined;
				} else if (e.type === "message" && e.message.role === "user") {
					if (pending >= 0) { items.push({ user: e, cpIdx: pending }); pending = -1; lastUser = undefined; }
					else lastUser = e;
				}
			});
			const labels = items.map((it) => {
				const t = promptText(it.user.message.content);
				return `${hhmm(it.user.timestamp)}  ${t.length > 70 ? t.slice(0, 69) + "…" : t || "(no text)"}`;
			});
			const UNDO = "↩ Undo last file rewind";
			const list = [...(undo.length ? [UNDO] : []), ...labels.slice().reverse()];
			if (!list.length) return ctx.ui.notify("No checkpoints in this branch", "warning");
			const choice = await ctx.ui.select("Rewind to prompt:", list);
			if (!choice) return;

			if (choice === UNDO) {
				const tree = undo.pop()!;
				const ok = await applyTree(repo, tree, trackedPaths(branch));
				return ctx.ui.notify(ok ? "Files restored to before last rewind" : "Undo failed", ok ? "info" : "error");
			}

			const it = items[labels.indexOf(choice)];
			const mode = await ctx.ui.select("Restore:", ["Files + chat", "Chat only", "Files only"]);
			if (!mode) return;

			if (mode !== "Chat only") {
				const cp = branch[it.cpIdx];
				const patches = new Map<string, string | null>();
				for (const e of branch.slice(it.cpIdx + 1))
					if (e.type === "custom" && e.customType === PATCH && !patches.has(e.data.path)) patches.set(e.data.path, e.data.blob);
				const target = patches.size ? await withPatches(repo, cp.data.tree, patches) : cp.data.tree;
				const prev = target && (await applyTree(repo, target, trackedPaths(branch)));
				if (!prev) return ctx.ui.notify("File restore failed", "error");
				undo.push(prev);
				ctx.ui.notify("Files restored", "info");
			}
			if (mode !== "Files only") await ctx.navigateTree(it.user.id, { summarize: false });
		},
	});
}
