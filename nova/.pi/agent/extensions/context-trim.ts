/**
 * Trims fixed per-request context without removing functionality (measured: 34,430 → 28,049 tokens).
 * Output is identical on every request, so the cached prefix stays stable.
 *
 * 1. `process`: replace codemode's ~3k-token return-type note with a pointer to describeTool("process").
 * 2. Hide declarations of rarely used tools; they stay active and callable through codemode.
 * 3. Drop user-invoked skills from the prompt list; `/skill:<name>` and `/ponytail-*` still work.
 * 4. Keep one copy of the identical codegraph_* rule line instead of eight.
 */
import { Type } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const HIDDEN = ["bg_wait", "codegraph_status", "generate_image"];
const UNLISTED_SKILLS = [
	"ponytail", // its rules are already injected by the ponytail extension
	"ponytail-help",
	"ponytail-gain",
	"ponytail-debt",
	"pi-lens-write-ast-grep-rule",
	"pi-lens-write-tree-sitter-rule",
];

export default function (pi: ExtensionAPI) {
	// prepareLoadout only runs on an active tool, so this carrier tool exists and hides itself.
	pi.registerTool({
		name: "context_trim",
		label: "context_trim",
		description: "internal",
		parameters: Type.Object({}),
		execute: async () => ({ content: [{ type: "text", text: "" }], details: undefined }),
		prepareLoadout: (loadout: any) => {
			const descriptions: Record<string, string> = {};
			const proc = loadout.declared.find((t: any) => t.name === "process");
			if (proc) {
				descriptions.process = `${proc.description}\n\nCodemode: \`tools.process(args)\` resolves to a structured object; \`describeTool("process")\` gives its type.`;
			}
			return { descriptions, hiddenDeclarations: ["context_trim", ...HIDDEN] };
		},
	} as any);

	pi.on("before_agent_start", (event: any) => {
		const o = event.systemPromptOptions;
		if (o.skills) o.skills = o.skills.filter((s: any) => !UNLISTED_SKILLS.includes(s.name));
		if (o.toolGuidelines) {
			for (const name of Object.keys(o.toolGuidelines)) {
				if (name.startsWith("codegraph_") && name !== "codegraph_search") delete o.toolGuidelines[name];
			}
		}
	});
}
