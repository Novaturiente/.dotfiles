/**
 * Footer status: Claude subscription usage (5h session window + weekly).
 * Source: Anthropic OAuth usage endpoint, same data Claude Code's statusline shows.
 * Token read from ~/.claude/.credentials.json on every fetch, so Claude Code's refreshes are picked up.
 * All pi processes (and usage-panel.ts) share one file cache, so the endpoint is hit at most once per
 * window no matter how many sessions run; a failure (429) backs every process off together.
 */
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const POLL_MS = 5 * 60_000;
const CACHE = `${homedir()}/.cache/claude-usage.json`;
// written by the patched pi-claude-code-provider on every response (rate_limit_event.unifiedWindows)
const LIVE = `${homedir()}/.cache/claude-usage-live.json`;

type Win = { utilization: number | null; resets_at: string | null } | null;
export type Cached = { data?: any; at: number; err?: string; backoffUntil?: number };

async function readJson(path: string): Promise<any> {
	try {
		return JSON.parse(await readFile(path, "utf8"));
	} catch {
		return undefined; // missing or corrupt: treat as absent
	}
}

/** Overlay the provider's per-response 5h/7d windows onto the endpoint data when they are newer. */
function withLive(c: Cached, live: any): Cached {
	if (!live?.windows || !(live.at > c.at)) return c;
	const data = structuredClone(c.data ?? {});
	for (const [key, kind] of [["five_hour", "session"], ["seven_day", "weekly_all"]]) {
		const w = live.windows[key];
		if (typeof w?.utilization !== "number") continue;
		const pct = w.utilization * 100; // Claude sends a 0..1 fraction
		const reset = w.resetsAt ? new Date(w.resetsAt < 1e11 ? w.resetsAt * 1000 : w.resetsAt).toISOString() : null;
		data[key] = { ...data[key], utilization: pct, resets_at: reset };
		const l = data.limits?.find((x: any) => x.kind === kind);
		if (l) Object.assign(l, { percent: pct, resets_at: reset });
	}
	return { ...c, data, at: live.at, err: undefined };
}

/** Usage (endpoint cache + live overlay); fetches only when both are older than maxAge and no backoff is active. */
export async function cachedUsage(maxAge = POLL_MS): Promise<Cached> {
	let c: Cached = (await readJson(CACHE)) ?? { at: 0 };
	const live = await readJson(LIVE);
	const now = Date.now();
	const merged = withLive(c, live);
	if ((merged.data && now - merged.at < maxAge) || now < (c.backoffUntil ?? 0)) return merged;
	const save = () => mkdir(`${homedir()}/.cache`, { recursive: true }).then(() => writeFile(CACHE, JSON.stringify(c)));
	// ponytail: soft lock, other processes skip for 15s while this one fetches; racy but cuts the stampede
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

export default function (pi: ExtensionAPI) {
	let timer: ReturnType<typeof setInterval> | null = null;

	const pct = (w: Win) => {
		const v = Math.round(w?.utilization ?? 0);
		// green <50 · yellow <70 · orange <90 · red ≥90 (same tiers as statusline-tweaks ctx)
		const h = v >= 90 ? [255, 95, 95] : v >= 70 ? [255, 135, 0] : v >= 50 ? [255, 215, 95] : [95, 215, 95];
		return `\x1b[38;2;${h.join(";")}m${v}%\x1b[39m`;
	};

	const refresh = async (ctx: ExtensionContext) => {
		const u = (await cachedUsage()).data;
		if (!u) return; // keep last value (429, expired token, offline)
		const t = ctx.ui.theme;
		ctx.ui.setStatus("usage", t.fg("accent", "5h:") + pct(u.five_hour) + t.fg("muted", " - ") + t.fg("accent", "WK:") + pct(u.seven_day));
	};

	pi.on("session_start", (_e, ctx) => {
		refresh(ctx);
		timer ??= setInterval(() => refresh(ctx), POLL_MS);
	});

	// cache read is cheap; the cache decides whether to hit the network
	pi.on("agent_settled", (_e, ctx) => refresh(ctx));

	pi.on("session_shutdown", () => {
		if (timer) clearInterval(timer);
		timer = null;
	});
}
