/**
 * MCP servers = global list + nearest project `.mcp.json` (Claude Code format).
 * Same name in both → project wins, so repo configs shared with Claude Code
 * devs override personal defaults.
 * Global list lives in ~/.pi/agent/mcp-global.json, NOT mcp.json: pi's built-in
 * mcp.json always beats extension-registered servers, which would invert priority.
 * Project `.mcp.json` only read under ~/Projects (stdio servers run commands).
 */
import type { ExtensionAPI, McpServerConfig } from "@earendil-works/pi-coding-agent";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

const ROOT = join(homedir(), "Projects");
const GLOBAL = join(homedir(), ".pi/agent/mcp-global.json");

function readServers(file: string): Record<string, McpServerConfig> {
	try {
		return JSON.parse(readFileSync(file, "utf8")).mcpServers ?? {};
	} catch (e) {
		console.error(`project-mcp: bad ${file}: ${(e as Error).message}`);
		return {};
	}
}

function findProjectDir(): string | undefined {
	let dir = process.cwd();
	if (dir !== ROOT && !dir.startsWith(`${ROOT}/`)) return;
	while (!existsSync(join(dir, ".mcp.json"))) {
		if (dir === ROOT) return;
		dir = dirname(dir);
	}
	return dir;
}

export default function (pi: ExtensionAPI) {
	const servers: Record<string, McpServerConfig> = existsSync(GLOBAL) ? readServers(GLOBAL) : {};
	const projectDir = findProjectDir();
	if (projectDir) {
		for (const [name, config] of Object.entries(readServers(join(projectDir, ".mcp.json")))) {
			servers[name] = { cwd: projectDir, ...config };
		}
	}
	for (const [name, config] of Object.entries(servers)) {
		try {
			pi.registerMcpServer(name, config);
		} catch (e) {
			console.error(`project-mcp: skipped ${name}: ${(e as Error).message}`);
		}
	}
}
