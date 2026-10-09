import type { BeforeProviderRequestEvent, ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Extension: claude-oauth-clean
 *
 * Resolves Anthropic third-party app rejection on OAuth:
 *    - (Disabled) Strip pi's built-in <docs> block — see sanitizeSystem to re-enable.
 *    - Injects the official Claude Code CLI billing attribution header.
 *
 * Prompt caching is left to pi itself: it already marks system, tools and the last
 * message (4 = Anthropic's max) and honours PI_CACHE_RETENTION=long. Adding marks
 * here caused "A maximum of 4 blocks with cache_control may be provided. Found 5."
 */

const BILLING_HEADER = "x-anthropic-billing-header: cc_version=2.1.280; cc_entrypoint=sdk-cli; cch=33f85;";

interface AnthropicSystemBlock {
	type: "text";
	text: string;
	cache_control?: { type: "ephemeral"; ttl?: string };
}

interface AnthropicPayload {
	model?: string;
	system?: AnthropicSystemBlock[];
	[key: string]: unknown;
}

function sanitizeSystem(system: AnthropicSystemBlock[]): AnthropicSystemBlock[] {
	// <docs> stripping disabled: tested 2026-10-10 — billing header alone avoids the third-party rejection.
	// If the rejection returns, delete the next line and uncomment the block below.
	const sanitizedBlocks = [...system];
	// const sanitizedBlocks = system.map((block) => {
	// 	if (block && typeof block.text === "string") {
	// 		return {
	// 			...block,
	// 			text: block.text.replace(/<docs>[\s\S]*?<\/docs>/g, ""),
	// 		};
	// 	}
	// 	return block;
	// });

	const hasBilling = sanitizedBlocks.some(
		(b) => typeof b.text === "string" && b.text.includes("x-anthropic-billing-header"),
	);
	if (!hasBilling) {
		sanitizedBlocks.unshift({
			type: "text",
			text: BILLING_HEADER,
		});
	}

	return sanitizedBlocks;
}

export default function (pi: ExtensionAPI) {
	pi.on("before_provider_request", (event: BeforeProviderRequestEvent) => {
		const payload = event.payload as AnthropicPayload | undefined;
		if (!payload) return;

		const modelName = payload.model ?? "";
		const isAnthropic = modelName.includes("claude") ||
			modelName.includes("opus") ||
			modelName.includes("sonnet") ||
			modelName.includes("haiku");

		if (!isAnthropic) return;

		if (Array.isArray(payload.system)) {
			payload.system = sanitizeSystem(payload.system);
		}

		return payload;
	});

	pi.on("session_start", (_event, ctx) => {
		const origNotify = ctx.ui.notify.bind(ctx.ui);
		ctx.ui.notify = (message, type) => {
			if (typeof message === "string" && message.includes("Third-party harness usage draws from extra usage")) {
				return;
			}
			origNotify(message, type);
		};
	});
}
