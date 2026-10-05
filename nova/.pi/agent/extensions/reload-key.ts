/**
 * Alt+Shift+R → reload extensions/settings/themes (same as built-in /reload).
 * Shortcut ctx has no reload(), and built-in /reload isn't dispatchable from an extension,
 * so route through an extension command whose ctx does have reload().
 */
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.registerCommand("reload-now", {
		description: "Reload extensions, settings and themes",
		handler: async (_a: string, ctx: ExtensionCommandContext) => { await ctx.reload(); }, // old ctx is stale after this; don't touch it
	});
	pi.registerShortcut("alt+shift+r", {
		description: "Reload pi",
		handler: () => pi.sendUserMessage("/reload-now", { expandPromptTemplates: true }),
	});
}
