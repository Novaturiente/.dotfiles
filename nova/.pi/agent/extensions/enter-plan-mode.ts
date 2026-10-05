/**
 * Claude Code style EnterPlanMode: lets the agent ask to switch into plan mode.
 * Plan-mode backend agnostic: the only coupling is PLAN_COMMAND. Swapping plan
 * extensions = change this constant if the new one uses a different command.
 */
import { Type } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Any plan extension whose command accepts "<cmd> <prompt>" works here.
const PLAN_COMMAND = "/plan";

export default function (pi: ExtensionAPI) {
	let pending: string | undefined;

	pi.registerTool({
		name: "enter_plan_mode",
		label: "Enter plan mode",
		description:
			"Ask the user to switch into read-only plan mode before non-trivial work: multi-file changes, refactors, migrations, " +
			"architecture choices, production-touching changes, or requests with more than one plausible reading. " +
			"Skip for small, clear, single-file fixes. The user confirms; on approval planning starts when this turn ends. Call it alone.",
		parameters: Type.Object({
			task: Type.String({ description: "The planning request, restated as a complete self-contained prompt" }),
		}),
		async execute(_id, params, _signal, _onUpdate, ctx) {
			if (!ctx.hasUI) throw new Error("No interactive UI; plan mode needs a user. Proceed without it.");
			const ok = await ctx.ui.confirm("Enter plan mode?", params.task);
			if (!ok) {
				return { content: [{ type: "text", text: "User declined plan mode. Continue normally." }], details: {} };
			}
			pending = params.task;
			return {
				content: [{ type: "text", text: "Plan mode starts when this turn ends. Stop now." }],
				details: { task: params.task },
				terminate: true,
			};
		},
	});

	// Plan commands require an idle session, so dispatch only once Pi fully settles.
	pi.on("agent_settled", () => {
		if (!pending) return;
		const task = pending;
		pending = undefined;
		pi.sendUserMessage(`${PLAN_COMMAND} ${task}`, { expandPromptTemplates: true });
	});
}
