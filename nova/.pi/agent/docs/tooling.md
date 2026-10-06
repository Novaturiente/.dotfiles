# Pi tooling reference (read on demand, not auto-loaded)

Pointed to from `~/.pi/agent/AGENTS.md`. Read when editing MCP/subagent config or debugging tool availability.

## MCP plumbing
- Pi built-in MCP (no `mcp` gateway tool).
- `extensions/project-mcp.ts` merges global `~/.pi/agent/mcp-global.json` with nearest `.mcp.json` for repos under `~/Projects/`; same server name → project wins.
- Never create `~/.pi/agent/mcp.json` — pi makes it beat project servers.
- Tools named `mcp__<server>__<tool>`, called from `codemode` (find with `searchTools()`; usage notes + tool list via `describeNamespace("serena")`).
- Every server uses default `codemode` exposure (none `direct`); don't add `exposure` fields. `"defaultTools": ["+codemode"]` in settings keeps codemode on.
- Status: footer `🔌 MCP: <servers> (<connected>)` from `extensions/mcp-status.ts`; details in `/mcp`. `pi mcp list` doesn't see extension servers.

## Local package patches
- `patches/*.patch` fix installed packages (pi-plan-mode symlink settings, claude-code-provider usage windows). `pi update` wipes them.
- After any `pi update`: `~/.pi/agent/scripts/apply-patches.sh` (idempotent; new patch → add its prefix→dir case), then `scripts/build-rpiv-bundles.sh`, then `/reload`.

## Subagent tool grants
- `subagents.agentOverrides` in `settings.json` grants scout/worker/reviewer/oracle/researcher: codegraph_*, codemode, lens_diagnostics, agent_browser*, `mcp:context7`, `inheritSkills: true`.
- Serena: full `mcp:serena` for worker only; scout/reviewer/oracle get read-only `mcp:serena/<tool>` selectors.
- Web search: oracle/researcher only.
- Scout pinned to `pi-claude-code-provider/haiku`.

## Browser (agent_browser) quick flow
`["open","<url>"]` → `["snapshot","-i"]` → `["click","@eN"]` / `["fill","@eN","text"]` → re-snapshot after page changes → `["close"]`. Fixed sequences → `batch --bail`; loops/branches → `agent_browser_code`; QA/Electron/extras → `agent_browser_tools`. `sessionMode: "fresh"` for clean launch (e.g. `--headed`). Localhost reachable directly.
