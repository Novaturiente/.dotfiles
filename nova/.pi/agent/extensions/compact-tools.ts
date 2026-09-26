/**
 * Compact tool display: one line call + one line result summary.
 * Full output only when expanded (ctrl+o).
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	createBashTool,
	createEditTool,
	createFindTool,
	createGrepTool,
	createLsTool,
	createReadTool,
	createWriteTool,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { homedir } from "os";

const short = (p: string) =>
	p?.startsWith(homedir()) ? `~${p.slice(homedir().length)}` : p || "";

const cache = new Map<string, ReturnType<typeof build>>();
const build = (cwd: string) => ({
	read: createReadTool(cwd),
	bash: createBashTool(cwd),
	edit: createEditTool(cwd),
	write: createWriteTool(cwd),
	find: createFindTool(cwd),
	grep: createGrepTool(cwd),
	ls: createLsTool(cwd),
});
const tools = (cwd: string) => {
	let t = cache.get(cwd);
	if (!t) cache.set(cwd, (t = build(cwd)));
	return t;
};

const textOf = (result: any) => {
	const c = result.content?.find((c: any) => c.type === "text");
	return c?.type === "text" ? c.text : "";
};

export default function (pi: ExtensionAPI) {
	const base = tools(process.cwd());

	// name -> [renderCall, summary label]
	const defs: Array<{
		name: keyof ReturnType<typeof build>;
		call: (args: any, theme: any) => string;
		summary: (out: string, args: any, theme: any) => string;
	}> = [
		{
			name: "read",
			call: (a, t) =>
				`${t.fg("toolTitle", t.bold("read"))} ${t.fg("accent", short(a.path))}`,
			summary: (o, _a, t) => t.fg("muted", `${o.split("\n").length} lines`),
		},
		{
			name: "bash",
			call: (a, t) => {
				const c = a.command ?? "";
				return (
					t.fg("toolTitle", t.bold("$ ")) +
					t.fg("accent", c.length > 100 ? `${c.slice(0, 97)}...` : c)
				);
			},
			summary: (o, _a, t) => {
				const m = o.match(/exit code: (\d+)/);
				const code = m ? Number(m[1]) : 0;
				const lines = o.split("\n").filter((l: string) => l.trim()).length;
				return (
					(code ? t.fg("error", `exit ${code}`) : t.fg("success", "ok")) +
					t.fg("muted", ` · ${lines} lines`)
				);
			},
		},
		{
			name: "edit",
			call: (a, t) =>
				`${t.fg("toolTitle", t.bold("edit"))} ${t.fg("accent", short(a.path))}` +
				t.fg("muted", a.edits ? ` (${a.edits.length} edits)` : ""),
			summary: (o, _a, t) =>
				/error/i.test(o)
					? t.fg("error", o.split("\n")[0])
					: t.fg("success", "applied"),
		},
		{
			name: "write",
			call: (a, t) =>
				`${t.fg("toolTitle", t.bold("write"))} ${t.fg("accent", short(a.path))}` +
				t.fg("muted", a.content ? ` (${a.content.split("\n").length} lines)` : ""),
			summary: (o, _a, t) =>
				/error/i.test(o)
					? t.fg("error", o.split("\n")[0])
					: t.fg("success", "written"),
		},
		{
			name: "grep",
			call: (a, t) =>
				`${t.fg("toolTitle", t.bold("grep"))} ${t.fg("accent", `/${a.pattern ?? ""}/`)}` +
				t.fg("muted", ` in ${short(a.path ?? ".")}`),
			summary: (o, _a, t) =>
				t.fg("muted", `${o.trim() ? o.trim().split("\n").length : 0} matches`),
		},
		{
			name: "find",
			call: (a, t) =>
				`${t.fg("toolTitle", t.bold("find"))} ${t.fg("accent", a.pattern ?? "")}` +
				t.fg("muted", ` in ${short(a.path ?? ".")}`),
			summary: (o, _a, t) =>
				t.fg("muted", `${o.trim() ? o.trim().split("\n").length : 0} files`),
		},
		{
			name: "ls",
			call: (a, t) =>
				`${t.fg("toolTitle", t.bold("ls"))} ${t.fg("accent", short(a.path ?? "."))}`,
			summary: (o, _a, t) =>
				t.fg("muted", `${o.trim() ? o.trim().split("\n").length : 0} entries`),
		},
	];

	for (const def of defs) {
		pi.registerTool({
			name: def.name,
			label: def.name,
			description: base[def.name].description,
			parameters: base[def.name].parameters,
			async execute(id, params, signal, onUpdate, ctx: any) {
				return tools(ctx?.cwd ?? process.cwd())[def.name].execute(
					id,
					params,
					signal,
					onUpdate,
				);
			},
			renderCall(args, theme) {
				return new Text(def.call(args, theme), 0, 0);
			},
			renderResult(result, { expanded, isPartial }, theme) {
				if (isPartial) return new Text(theme.fg("warning", "..."), 0, 0);
				const out = textOf(result);
				let text = def.summary(out, (result as any).args ?? {}, theme);
				if (expanded && out) {
					text += `\n${out
						.split("\n")
						.map((l: string) => theme.fg("toolOutput", l))
						.join("\n")}`;
				}
				return new Text(text, 0, 0);
			},
		});
	}
}
