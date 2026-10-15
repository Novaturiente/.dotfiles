# swarm — background subagents for pi

Each subagent is a full `pi` (tools, MCP via codemode, skills) running in a window of a
hidden tmux session `swarm-<rootId8>`. Main pi → children → grandchildren (`maxDepth` 2);
grandchildren have no `swarm` tool.

## Files
- `index.ts` — the extension. Parent role: `swarm` tool + 1 s supervision loop. Child role
  (env `PI_SWARM_ID`): writes state/activity/result, reads inbox, `ask_parent` tool.
- `core.mjs` — file store, agent definitions → pi CLI args, tmux launch/stop/open, formatting.
- `ctl.mjs` — panel actions: `ctl.mjs open|read|stop|resume <root> <id>`.
- `config.json` — limits, child extensions, tool → extension map, agent/skill dirs.
- Panel: `../panel/` (generic; see its README).

## State: `~/.local/state/pi-swarm/<mainSessionId>/agents/<id>/`
| file | writer | content |
|---|---|---|
| `meta.json` | spawner | parent, depth, agent, task, cwd, model, notify, after, ownerPane |
| `ctl.json` | parent | pane, launchedAt, queued/failed/stopped status, error, reaped |
| `state.json` | child | status, run count, current tool, cost, ctx tokens, sessionFile |
| `activity.jsonl` | child | one line per tool call |
| `result.md` | child | final assistant text of the last run (the report) |
| `inbox/` `questions/` `answers/` | both | messages to the child, its questions, answers |
| `seen.json` | parent | which reports/questions were already delivered |
| `session/` | pi | the child's session file (resume uses it) |

## Delivery (cache-safe)
Tools are registered once; nothing changes the system prompt. Reports are appended as
`customType: "swarm"` messages, batched for 1.5 s: idle parent → `triggerTurn`, busy →
`deliverAs: "steer"`, `notify: next` → `nextTurn`, `quiet` → panel only. Reports over
`inlineChars` are cut to 600 chars plus a `swarm read` pointer. Children being collected by
`swarm wait` are skipped by the notifier.

## Lifecycle
queued → starting → running ⇄ waiting (ask_parent) → done. A live pane that vanishes →
failed "process exited". Starting for 2 min → stopped. Running with no tool in flight and no
activity for `stallMin` (10) → stopped "stalled". Running or waiting past `timeoutMin` (45) →
stopped. Done for `reapAfterMin`
(default 0 = at once) → process killed, unless opened beside main or its own children still
run; `resume`/`send` relaunch it from its session file. Main pi `/quit` stops the whole tree and closes the panel.

## Panel
Row = `id agent` + elapsed, then the purpose (`title` given at spawn, else the task's first
sentence), then current tool / cost. The pane hides itself 5 s after every subagent finished
(unless another source has rows); `/swarm` shows or hides it again with the same rows.
It shares the panel tab "Agent" (priority 20) with the todo list, so it covers the file tree tab while subagents run
and the tree comes back when it closes.

## Agents
`*.md` with frontmatter under `agentDirs` (recursive): name, description, tools
(`mcp:x` → `mcp__x*` + codemode), extensions, skills, model, thinking,
systemPromptMode (replace|append), inheritProjectContext (default true),
inheritGlobalContext (default false: `~/.pi/agent/AGENTS.md` is written for the main agent).
Tools listed in `toolExtensions` pull in the extension that provides them.
Model: spawn's `model`, else the agent file's `model`, else `defaultModel` in config.json.

## Prompt cache
The child's system prompt and tool descriptions hold nothing per child; its id, depth and parent
are the first line of its first message. So children of one agent type, model and folder share
the cached prefix (measured: a later sibling read 4957 tokens from cache, wrote 132).

## File claims
A child's first `edit`/`write` to a file claims it (`claims/` in the state dir, real path, so
symlinks match). Another active subagent's edit of that file is blocked with the holder's id and
purpose; main is blocked too but never claims. A parent's claim passes down to its children.
A file stays held while its owner or anything it delegated to is still working; a child's edit
of a file its ancestor holds keeps the ancestor's claim. Each finished run releases its claims
(unless its children still work). shortcut: bash writes are not seen; the report rules forbid that workaround.

## Parent death
Main writes `main.pid`; every child checks its parent's pid each second. Parent gone (crash,
kill, closed pane) → the child aborts, is marked stopped "parent exited" and exits, so the
whole tree ends within ~2 s. The panel tabs check the owning pi the same way and close.

## MCP
A child starts only the MCP servers its agent lists (`mcp:x`) plus spawn's `mcp: [..]`;
none otherwise (`--no-mcp`). `PI_MCP_ONLY` tells `../project-mcp.ts` which to register.
