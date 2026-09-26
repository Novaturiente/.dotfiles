/**
 * Footer status: Claude subscription usage (5h session window + weekly).
 * Source: Anthropic OAuth usage endpoint, same data Claude Code's statusline shows.
 * Token read from ~/.claude/.credentials.json on every poll, so Claude Code's refreshes are picked up.
 */
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const POLL_MS = 5 * 60_000;
const MIN_GAP_MS = 60_000; // throttle refresh after each turn

type Win = { utilization: number | null; resets_at: string | null } | null;

async function fetchUsage(): Promise<{ five_hour: Win; seven_day: Win }> {
	const creds = JSON.parse(await readFile(`${homedir()}/.claude/.credentials.json`, "utf8"));
	const res = await fetch("https://api.anthropic.com/api/oauth/usage", {
		headers: {
			Authorization: `Bearer ${creds.claudeAiOauth.accessToken}`,
			"anthropic-beta": "oauth-2025-04-20",
		},
		signal: AbortSignal.timeout(10_000),
	});
	if (!res.ok) throw new Error(`usage ${res.status}`);
	return res.json();
}

export default function (pi: ExtensionAPI) {
	let timer: ReturnType<typeof setInterval> | null = null;
	let last = 0;

	const pct = (ctx: ExtensionContext, w: Win) => {
		const t = ctx.ui.theme;
		const v = Math.round(w?.utilization ?? 0);
		return t.fg(v >= 90 ? "error" : v >= 70 ? "warning" : "text", `${v}%`);
	};

	const refresh = async (ctx: ExtensionContext) => {
		last = Date.now();
		try {
			const u = await fetchUsage();
			const t = ctx.ui.theme;
			ctx.ui.setStatus(
				"usage",
				t.fg("muted", "5h ") + pct(ctx, u.five_hour) + t.fg("muted", " · wk ") + pct(ctx, u.seven_day),
			);
		} catch {
			// ponytail: keep last value on failure (expired token, offline); Claude Code refreshes the token
		}
	};

	pi.on("session_start", (_e, ctx) => {
		refresh(ctx);
		timer ??= setInterval(() => refresh(ctx), POLL_MS);
	});

	pi.on("agent_settled", (_e, ctx) => {
		if (Date.now() - last > MIN_GAP_MS) refresh(ctx);
	});

	pi.on("session_shutdown", () => {
		if (timer) clearInterval(timer);
		timer = null;
	});
}
