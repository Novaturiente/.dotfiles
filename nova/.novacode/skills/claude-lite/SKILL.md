---
name: claude-lite
description: How a batch job or shell script must call Claude non-interactively. Use when writing or editing any script, cron/timer job or pipeline that shells out to `claude -p`, `pi -p` or `novacode -p`.
---

# claude-lite

Batch jobs and scripts that shell out to Claude use `claude-lite` (in `~/.local/bin`). It is `claude -p` with no settings, MCP servers, tools, slash commands, session files or auto-memory, so each call starts fast and clean.

Rules:

- Pass `--model`, `--output-format` and other `claude -p` flags straight through.
- Never plain `claude -p`: it loads every MCP server in `~/.claude.json` on each call.
- Never `pi -p` or `novacode -p`: full harness startup per call.
- Re-enable only what the job needs. A tool must be passed to both flags, else it is permission-denied: `--tools Read --allowedTools Read`.
- No CLAUDE.md or rules load, so put every instruction the job needs in the prompt itself.
- Keep parallelism at 5 calls or fewer.
