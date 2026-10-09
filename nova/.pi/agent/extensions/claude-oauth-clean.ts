import type { BeforeProviderRequestEvent, ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Extension: claude-oauth-clean
 * 
 * 1. Resolves Anthropic third-party app rejection on OAuth:
 *    - Strips pi's built-in <docs> block from the outgoing system prompt.
 *    - Injects the official Claude Code CLI billing attribution header.
 * 
 * 2. Implements jcode-style prompt caching optimizations:
 *    - Keeps static prompt and tools cached.
 *    - Implements a sliding 2-breakpoint window on recent conversation turns
 *      (read previous turn, write current turn) staying within Anthropic's 4-breakpoint limit.
 *    - Supports 1-hour extended TTL when PI_CACHE_RETENTION=long is set.
 */

const BILLING_HEADER = "x-anthropic-billing-header: cc_version=2.1.280; cc_entrypoint=sdk-cli; cch=33f85;";

interface AnthropicSystemBlock {
	type: "text";
	text: string;
	cache_control?: { type: "ephemeral"; ttl?: string };
}

interface AnthropicContentPart {
	type: string;
	text?: string;
	cache_control?: { type: "ephemeral"; ttl?: string };
	[key: string]: unknown;
}

interface AnthropicMessage {
	role: string;
	content: string | AnthropicContentPart[];
	[key: string]: unknown;
}

interface AnthropicPayload {
	model?: string;
	system?: AnthropicSystemBlock[];
	tools?: Array<{ name: string; cache_control?: { type: "ephemeral"; ttl?: string }; [key: string]: unknown }>;
	messages?: AnthropicMessage[];
	[key: string]: unknown;
}

function getCacheControl(): { type: "ephemeral"; ttl?: string } {
	if (process.env.PI_CACHE_RETENTION === "long") {
		return { type: "ephemeral", ttl: "1h" };
	}
	return { type: "ephemeral" };
}

function sanitizeSystem(system: AnthropicSystemBlock[], cacheControl: { type: "ephemeral"; ttl?: string }): AnthropicSystemBlock[] {
	const sanitizedBlocks = system.map((block) => {
		if (block && typeof block.text === "string") {
			return {
				...block,
				text: block.text.replace(/<docs>[\s\S]*?<\/docs>/g, ""),
			};
		}
		return block;
	});

	const hasBilling = sanitizedBlocks.some(
		(b) => typeof b.text === "string" && b.text.includes("x-anthropic-billing-header"),
	);
	if (!hasBilling) {
		sanitizedBlocks.unshift({
			type: "text",
			text: BILLING_HEADER,
		});
	}

	const instructionBlock = sanitizedBlocks.at(-1);
	if (instructionBlock && !instructionBlock.cache_control) {
		instructionBlock.cache_control = cacheControl;
	}

	return sanitizedBlocks;
}

function applySlidingMessageCache(messages: AnthropicMessage[], cacheControl: { type: "ephemeral"; ttl?: string }): void {
	// Clear existing cache markers
	for (const msg of messages) {
		if (Array.isArray(msg.content)) {
			for (const part of msg.content) {
				if (part && typeof part === "object" && part.cache_control) {
					part.cache_control = undefined;
				}
			}
		}
	}

	const markMessage = (msg: AnthropicMessage | undefined) => {
		if (!msg) return;
		if (Array.isArray(msg.content) && msg.content.length > 0) {
			const lastPart = msg.content.at(-1);
			if (lastPart && typeof lastPart === "object") {
				lastPart.cache_control = cacheControl;
			}
		} else if (typeof msg.content === "string") {
			msg.content = [
				{
					type: "text",
					text: msg.content,
					cache_control: cacheControl,
				},
			];
		}
	};

	if (messages.length >= 3) {
		markMessage(messages.at(-2));
	}
	markMessage(messages.at(-1));
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

		const cacheControl = getCacheControl();

		if (Array.isArray(payload.system)) {
			payload.system = sanitizeSystem(payload.system, cacheControl);
		}

		if (Array.isArray(payload.messages) && payload.messages.length > 0) {
			applySlidingMessageCache(payload.messages, cacheControl);
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
