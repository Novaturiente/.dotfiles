import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Extension: latest-models
 *
 * Version-less aliases anthropic/claude-haiku, anthropic/claude-sonnet, anthropic/claude-opus.
 * Each routes to the newest physical model of that family at request time, so configs
 * (subagent models, --model) never need a version bump. pi-subagents rejects partial ids,
 * but accepts registered virtual models.
 */

const FAMILIES = ["haiku", "sonnet", "opus"] as const;

// Undated ids only: claude-<family>-<major>[-<minor>]. Skips dated snapshots and the alias itself.
function version(id: string, family: string): number | undefined {
	const m = new RegExp(`^claude-${family}-(\\d+)(?:-(\\d+))?$`).exec(id);
	return m ? Number(m[1]) * 1000 + Number(m[2] ?? 0) : undefined;
}

export function newestId(ids: string[], family: string): string | undefined {
	let best: string | undefined;
	let bestV = -1;
	for (const id of ids) {
		const v = version(id, family);
		if (v !== undefined && v > bestV) {
			best = id;
			bestV = v;
		}
	}
	return best;
}

export default function (pi: ExtensionAPI) {
	for (const family of FAMILIES) {
		pi.registerVirtualModel({
			provider: "anthropic",
			id: `claude-${family}`,
			name: `Claude ${family[0].toUpperCase()}${family.slice(1)} (latest)`,
			thinkingLevels: ["off", "minimal", "low", "medium", "high", "xhigh"],
			route(request, ctx) {
				// Tool follow-ups and retries stay on the model that handled the turn (keeps cache + thinking signatures).
				const sticky = request.failed ?? request.previous;
				if (request.reason !== "user" && sticky) {
					return { model: sticky.model, thinkingLevel: sticky.thinkingLevel ?? request.thinkingLevel };
				}
				const ids = ctx.modelRegistry.getAvailable().filter((m) => m.provider === "anthropic").map((m) => m.id);
				const id = newestId(ids, family);
				const model = id && ctx.modelRegistry.find("anthropic", id);
				if (!model) throw new Error(`latest-models: no available anthropic claude-${family}-* model`);
				return { model, thinkingLevel: request.thinkingLevel };
			},
		});
	}
}
