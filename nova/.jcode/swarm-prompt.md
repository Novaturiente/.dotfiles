<!--
Global jcode swarm config (stowed from ~/.dotfiles/nova/.jcode/swarm-prompt.md).
Ported from pi's subagents.agentOverrides + ~/.pi/agent/agents/ on 2026-10-09.
Routes are Claude subscription OAuth (`claude-oauth:`), same billing as pi's
claude-code provider. Check availability with `swarm list_models`.
-->

Model routing for spawned swarm agents. Always pass `label`, `model` and `effort`.

## Roles (ported from pi)

| Role | Use for | `model` | `effort` | May spawn |
|---|---|---|---|---|
| scout | Recon: exploration over 3+ files, dir/architecture maps, "where/how is X done", long logs/docs. Read-only. Returns a compact summary with file:line refs. | `claude-oauth:claude-haiku-5-5` | `none` | no |
| worker | Bounded edits from a precise spec. | `claude-oauth:claude-sonnet-5-5` | `low` | no |
| reviewer | Bug/structure review of a diff. Read-only, no edits. | `claude-oauth:claude-sonnet-5-5` | default | no |
| oracle | Hard design/debugging second opinion. Read-only. | `claude-oauth:claude-opus-5-5` | `high` | no |
| researcher | Web research (Google via `agent-browser`, see `~/AGENTS.md`), docs via context7. Writes notes, not code. | `claude-oauth:claude-sonnet-5-5` | default | no |
| specialist | A persona from `~/.jcode/agents/<name>.md` (nextjs-pro, security-auditor, debugger, postgres-pro, ...; `ls ~/.jcode/agents` for the 36). | `claude-oauth:claude-sonnet-5-5` | `medium` | no |

- Use the role name in `label` (e.g. `scout: auth flow`, `reviewer: checkout diff`).
- Start the `prompt` with the role contract, e.g. "You are a read-only scout. Do not edit files." Read-only roles must be told so: jcode has no per-agent tool lists.
- Specialist: start the prompt with "First read `~/.jcode/agents/<name>.md` and follow it as your role (ignore its frontmatter `tools`/`model` lines)." then the task.
- Pick the narrowest role. Don't raise scout above Haiku unless its summary proved insufficient.
- Fan-outs (parallel review, review loops, parallel research, council) need an explicit user request.
- If a route is unavailable, omit `model` so the worker inherits the coordinator's model.

Structure guidance for spawned swarm agents:

- Always pass `label` when spawning so the swarm UI shows what each agent is for.
  The explicit `spawn` action rejects missing or blank labels.
- In normal and light-swarm mode, only the root session may spawn agents. Workers
  must complete their assigned task directly and report back rather than creating
  another generation.
- Recursive spawning is reserved for a root running in `swarm-deep` mode. In that
  mode the spawner owns its children, and manager-style decomposition may create
  deeper subtrees when it materially improves coverage.
