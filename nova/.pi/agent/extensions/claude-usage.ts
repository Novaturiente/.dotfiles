/**
 * Footer status: provider subscription usage (Claude 5h/WK or Antigravity 5h/WK per active model).
 * Source: Anthropic OAuth usage endpoint or Antigravity quota endpoint based on active provider.
 * All pi processes share file caches, so endpoints are hit at most once per window.
 */
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const POLL_MS = 5 * 60_000;
const CLAUDE_CACHE = `${homedir()}/.cache/claude-usage.json`;
const CLAUDE_LIVE = `${homedir()}/.cache/claude-usage-live.json`;
const ANTIGRAVITY_CACHE = `${homedir()}/.cache/antigravity-usage.json`;

type Win = { utilization: number | null; resets_at: string | null } | null;
export type Cached = { data?: any; at: number; err?: string; backoffUntil?: number; provider?: string };

async function readJson(path: string): Promise<any> {
	try {
		return JSON.parse(await readFile(path, "utf8"));
	} catch {
		return undefined;
	}
}

/** Overlay Claude per-response 5h/7d windows onto endpoint data when newer. */
function withLive(c: Cached, live: any): Cached {
	if (!live?.windows || !(live.at > c.at)) return c;
	const data = structuredClone(c.data ?? {});
	for (const [key, kind] of [["five_hour", "session"], ["seven_day", "weekly_all"]]) {
		const w = live.windows[key];
		if (typeof w?.utilization !== "number") continue;
		const pct = w.utilization * 100;
		const reset = w.resetsAt ? new Date(w.resetsAt < 1e11 ? w.resetsAt * 1000 : w.resetsAt).toISOString() : null;
		data[key] = { ...data[key], utilization: pct, resets_at: reset };
		const l = data.limits?.find((x: any) => x.kind === kind);
		if (l) Object.assign(l, { percent: pct, resets_at: reset });
	}
	return { ...c, data, at: live.at, err: undefined };
}

/** Claude usage fetch/cache */
export async function cachedClaudeUsage(maxAge = POLL_MS): Promise<Cached> {
	let c: Cached = (await readJson(CLAUDE_CACHE)) ?? { at: 0 };
	const live = await readJson(CLAUDE_LIVE);
	const now = Date.now();
	const merged = withLive(c, live);
	if ((merged.data && now - merged.at < maxAge) || now < (c.backoffUntil ?? 0)) return merged;
	const save = () => mkdir(`${homedir()}/.cache`, { recursive: true }).then(() => writeFile(CLAUDE_CACHE, JSON.stringify(c)));
	c.backoffUntil = now + 15_000;
	await save();
	try {
		const creds = JSON.parse(await readFile(`${homedir()}/.claude/.credentials.json`, "utf8"));
		const res = await fetch("https://api.anthropic.com/api/oauth/usage", {
			headers: { Authorization: `Bearer ${creds.claudeAiOauth.accessToken}`, "anthropic-beta": "oauth-2025-04-20" },
			signal: AbortSignal.timeout(10_000),
		});
		if (!res.ok) throw new Error(`usage endpoint HTTP ${res.status}`);
		c = { data: await res.json(), at: Date.now() };
	} catch (e: any) {
		c.err = String(e?.message ?? e);
		c.backoffUntil = Date.now() + (c.err.includes("429") ? POLL_MS : 60_000);
	}
	await save();
	return withLive(c, live);
}

/** Antigravity quota fetch/cache */
export async function cachedAntigravityUsage(maxAge = POLL_MS): Promise<Cached> {
	let c: Cached = (await readJson(ANTIGRAVITY_CACHE)) ?? { at: 0 };
	const now = Date.now();
	if ((c.data && now - c.at < maxAge) || now < (c.backoffUntil ?? 0)) return c;
	const save = () => mkdir(`${homedir()}/.cache`, { recursive: true }).then(() => writeFile(ANTIGRAVITY_CACHE, JSON.stringify(c)));
	c.backoffUntil = now + 15_000;
	await save();
	try {
		const auth = JSON.parse(await readFile(`${homedir()}/.pi/agent/auth.json`, "utf8"))?.antigravity;
		if (!auth?.access) throw new Error("No Antigravity credentials in auth.json");
		const res = await fetch("https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary", {
			method: "POST",
			headers: {
				Authorization: `Bearer ${auth.access}`,
				"Content-Type": "application/json",
				"User-Agent": "antigravity/cli/1.2.4 (aidev_client; os_type=linux; arch=amd64; cl=982146307; auth_method=consumer)",
			},
			body: JSON.stringify({}),
			signal: AbortSignal.timeout(10_000),
		});
		if (!res.ok) throw new Error(`Antigravity quota HTTP ${res.status}`);
		c = { data: await res.json(), at: Date.now() };
	} catch (e: any) {
		c.err = String(e?.message ?? e);
		c.backoffUntil = Date.now() + (c.err.includes("429") ? POLL_MS : 60_000);
	}
	await save();
	return c;
}

/** Normalized windows helper for Antigravity response based on model ID */
export function antigravityWindows(data: any, modelId = ""): { five_hour: Win; seven_day: Win } {
	if (!data?.groups) return { five_hour: null, seven_day: null };
	const is3P = /claude|gpt|sonnet|opus/i.test(modelId);
	const group = data.groups.find((g: any) =>
		is3P ? /claude|gpt/i.test(g.displayName) : /gemini/i.test(g.displayName),
	) ?? data.groups[0];
	if (!group?.buckets) return { five_hour: null, seven_day: null };

	const b5h = group.buckets.find((b: any) => b.window === "5h" || /5h|5-hour/i.test(b.bucketId));
	const bwk = group.buckets.find((b: any) => b.window === "weekly" || /weekly/i.test(b.bucketId));

	const toWin = (b: any): Win => {
		if (!b || b.remainingFraction == null) return null;
		const utilization = Math.max(0, Math.min(100, Math.round((1 - b.remainingFraction) * 100)));
		return { utilization, resets_at: b.resetTime ?? null };
	};

	return { five_hour: toWin(b5h), seven_day: toWin(bwk) };
}

/** Dynamic cached usage based on active provider */
export async function cachedUsage(maxAge = POLL_MS, provider = "claude", modelId = ""): Promise<Cached> {
	if (provider === "antigravity") {
		const r = await cachedAntigravityUsage(maxAge);
		const wins = antigravityWindows(r.data, modelId);
		return { ...r, provider: "antigravity", data: { ...r.data, ...wins } };
	}
	const r = await cachedClaudeUsage(maxAge);
	return { ...r, provider: "claude" };
}

export default function (pi: ExtensionAPI) {
	let timer: ReturnType<typeof setInterval> | null = null;

	const pct = (w: Win) => {
		const v = Math.round(w?.utilization ?? 0);
		const h = v >= 90 ? [255, 95, 95] : v >= 70 ? [255, 135, 0] : v >= 50 ? [255, 215, 95] : [95, 215, 95];
		return `\x1b[38;2;${h.join(";")}m${v}%\x1b[39m`;
	};

	const refresh = async (ctx: ExtensionContext) => {
		const provider = ctx.model?.provider === "antigravity" ? "antigravity" : "claude";
		const modelId = ctx.model?.id ?? "";
		const u = (await cachedUsage(POLL_MS, provider, modelId)).data;
		if (!u) return;
		const t = ctx.ui.theme;
		ctx.ui.setStatus("usage", t.fg("accent", "5h:") + pct(u.five_hour) + t.fg("muted", " - ") + t.fg("accent", "WK:") + pct(u.seven_day));
	};

	pi.on("session_start", (_e, ctx) => {
		refresh(ctx);
		timer ??= setInterval(() => refresh(ctx), POLL_MS);
	});

	pi.on("model_select", (_e, ctx) => refresh(ctx));
	pi.on("agent_settled", (_e, ctx) => refresh(ctx));

	pi.on("session_shutdown", () => {
		if (timer) clearInterval(timer);
		timer = null;
	});
}

