# Global Instructions (pi)

Never run sudo — ask user to run it. All dates/times in IST.
Project `AGENTS.md`/`CLAUDE.md` files add to these; on conflict, project file wins for that project.

## Email
Never use `eecglobal.dev@gmail.com` for home-server/self-hosted things (work only), even though it is git `user.email`.
- Local login that never sends mail → `nova@novarch.site` (default).
- Service really sends mail (reset, verify, invite) → `novaturiente@proton.me`.
- Unsure → `nova@novarch.site`, say so.

## Machine
`novahome` (Tailscale 100.88.215.101) = headless server, reached over SSH from laptop `novarch` (usually via `herdr --remote`).
- No GUI, display, clipboard. Never suggest `xclip`, `wl-paste`, `xdg-open`.
- Pasted screenshots land in `/tmp/herdr-clipboard-images-1000/`.
- Both machines have `/home/nova`. Never assume a file the user mentions is on this box — check here, then `ssh novarch 'ls <path>'`. Always say which host a path is on.
- Laptop files: `scp novarch:/path /tmp/` or `rsync -a novarch:/dir/ ~/mirror/dir/`. Prefix laptop paths with `novarch:`. Never ask user to copy by hand.
- Also a home server: Docker stacks + systemd **user** timers (no cron). Inventory: `~/Automation/CLAUDE.md` — read before touching anything self-hosted; update it when changing `~/Automation/`. Stacks also in `~/Jellyfin/`, `~/Immich/`, `~/searxng/`, `~/gotify/`, `~/DockerProjects/`.
- Coolify (`coolify.eecglobal.com`) deploys `~/Projects/` apps — separate from local containers. After any push from `~/Projects/`, follow the `coolify` skill's Post-Push Auto-Monitor unless user says skip.

## Rules
1. Read everything task-related first. Never end turn on a promise.
2. When to ask:
   - Clear default exists (project config/conventions, AGENTS.md, earlier answer) → use it, don't stall. Ponytail's "never stall on an answer you can default" applies only here.
   - No clear default → ask, never assume. Always ask for: >1 plausible reading, destructive/irreversible action, scope change, input only user has, production (auth, payments, DB schema, live data/routes).
   - One `ask_user_question` call, ≤3 questions, recommended option first.
   Plan shape (any plan: `/plan` mode, or after intake questions) — message, not a file unless asked:
   - **Rung**: which ponytail ladder rung stops here, why higher ones fail.
   - **Diff**: files touched, change in each. Fewest files that work.
   - **Check**: one runnable check for non-trivial logic.
   - **Skipped**: what was deliberately not built, and when to add it. No Skipped section = YAGNI not applied, cut again.
   After approval build only the approved plan; new scope found mid-build → report it, don't absorb it.
3. User describing/asking (not requesting change) → deliver assessment, no fix.
4. Before state-changing commands, confirm evidence supports that exact action.
5. Scope per ponytail: laziest working thing, no speculative error handling/flags/shims. Validate only at boundaries.
6. Report only verified work. Change not done until its check (typecheck/lint/tests or one runnable check) ran this session. Failures → show output.
7. Settled answers stay settled. Speed matters.
8. Multi-phase task → create `todo` list first, follow it. Mark item in_progress before starting, completed right after. New scope mid-task → add item.
9. Before `edit`, `read` the file in this session. Re-read after /reload, compaction, or if it was last read in an earlier turn. Read and edit are separate steps, never in the same parallel batch (pi-lens read-guard blocks otherwise).

## Final message
Overrides ponytail's "≤3 lines" and caveman terseness for the final message. Clear beats short.
- Open with one plain sentence (what happened / found).
- Then short bold headers + bullets, one fact each. Easy to scan.
- Gloss every identifier in plain language on first mention.
- No process narration, no arrow chains, no invented jargon.

## Coding style
- One unit, one job. Seams where change happens (data access, external services, UI, business rules). No single-implementation interfaces.
- Web basics: stateless handlers, work in DB (indexes, pagination), no N+1, slow work off request path.
- `~/Projects/` = Next.js/TS: render server-side where it helps SEO (public/marketing pages); client components only for interactivity. Colocate route code, lift to shared only at the second consumer. Validate with project's schema lib.

## Tools
Config details (MCP merge, subagent grants, browser flow): `~/.pi/agent/docs/tooling.md` — read only when editing that config or a tool seems missing.
- Web search → `google_search`; `pi_claude_code_provider_web_search` only if no other search tool exists.
- MCP tools (`mcp__<server>__<tool>`) → call via `codemode` (`searchTools()`), except context7: call directly. Never create `~/.pi/agent/mcp.json`.
- Symbol/caller/impact questions → `codegraph_*` or Serena via codemode, or async subagent. Text/config/dir-map → `scout` or grep. Library docs → context7.
- Browser → native `agent_browser` only; never `agent-browser` via bash, no browser MCP, no Playwright.
- Noisy output (tests, builds, lint, installs, `git log`/`diff`, logs) → filter at source: `2>&1 | tail -40` or `2>&1 | grep -iE "error|fail|warn" | head -50`; `git diff --stat` before full diff. Rerun unfiltered only if needed.

## Subagents
- Delegation pre-authorized: call `subagents_enable`, delegate without asking when a specialist fits or subtasks are independent; launch independent ones together, keep working, correct drift. Main agent coordinates.
- Narrowest agent: `scout` recon, `worker` bounded edits, `reviewer` review. User specialists in `~/.pi/agent/agents/` aren't in the prompt → run `subagent({action:"list", capabilities:true})` and pick narrowest match.
- Nesting depth 2: oracle/researcher → scout/worker/reviewer; worker → scout/reviewer; scout/reviewer are leaves.
- Explicit request needed for fan-outs (`/parallel-review`, `/review-loop`, `/parallel-research`, council) — cost real money.
- Recon → `scout` (Haiku; don't override model up unless its summary proved insufficient): exploration >3 files, dir/architecture mapping, "where/how is X done", long logs/docs. Ask for compact summary with file:line refs. Main thread reads only files it edits or must quote. Exceptions: symbol questions, one known file, whole-session-state repros.
- Always launch scout/worker/reviewer/oracle/researcher with `async: true` (their MCP/extension tools load only in background children; foreground fails).
- Researcher lacks `web_search`/`fetch_content`/`source_check` → tell it to use `google_search` (fallback `pi_claude_code_provider_web_search`) and `agent_browser`.
- Claude provider bug: never `subagent({workflow: true})` (arrives as string → `Unknown workflow resource 'true'`). Use separate `async: true` calls, or write script to file and pass `workflow: "./path.js"`. Max one foreground subagent call per turn.
- Child questions (`need_decision`/`interview_request` via `contact_supervisor`): don't answer yourself unless already settled in this conversation or AGENTS.md. Relay with `ask_user_question` (prefix header/question with agent name), reply via `subagent_supervisor({action:"reply", replyTo:<request id>, message})`. Several pending → `subagent_supervisor({action:"pending"})`, batch into one `ask_user_question` (≤4), reply per id. `progress_update` → no reply.

## Worktrees (mandatory for edits in a repo)
- Any file edit in a git project → `enter_worktree` (leave via `exit_worktree`). Never `git checkout -b`/`switch` in main checkout unless user asked.
- Assume other agents run in the repo: no stash/reset/clean/rebase in main checkout.
- Worktrees live in `<repo>/.claude/worktrees/`, shared with Claude Code sessions. Reuse one only if ALL hold, else make a new one:
  1. No other session inside: `for p in $(pgrep -x claude; pgrep -x pi); do readlink /proc/$p/cwd; done` lists no path under it (ignore your own pid). Pi may not change process cwd on `enter_worktree`, so also ask yourself whether another session could be using it — in doubt, new worktree.
  2. Clean: `git -C <wt> status --porcelain` empty.
  3. Its branch is the right target (or disposable and user said so).
- Main checkout gets writes only when user explicitly asked, in that message, on the branch already checked out.
- Copy `.env` in fresh worktrees. Install deps only if the repo has no warm-up script (e.g. EEC-Learning `scripts/worktree-warm.sh`) or `package.json`/lockfile differs from main — worktrees under the main checkout resolve its `node_modules` by upward lookup. Say which worktree you're in. Remove after merge.
- Never worktrees in `~/Automation/` or Docker stacks.

## Testing what you built
- Clean room: testing something built this session → fresh subagent, handed only the spec and how to run it, never your reasoning (builder tests the happy path). Exception: repro needs whole-session state → test in main thread, say which you used.
- Scoped runs: test changed code plus what it affects (callers, dependents, shared modules), reasoned from the change, not filenames. Full suite only if asked or blast radius is the whole suite. Report skipped scope; never imply full green when a subset ran.

## Scripts that call an LLM
Batch jobs/scripts that shell out to Claude → `claude-lite` (in `~/.local/bin`: `claude -p` with no settings, MCP, tools, slash commands, session files, or auto-memory). Pass `--model`, `--output-format` etc. through. Never plain `claude -p` (loads `~/.claude.json` MCP servers per call), never `pi -p` (extension startup + Claude Code underneath). Re-enable only what the job needs: pass the tool to both flags (`--tools Read --allowedTools Read`), else it is permission-denied. No CLAUDE.md/rules load, so put every instruction the job needs in the prompt. Keep parallelism ≤5.

## Dev servers
Check for an existing one first (`ss -ltnp | grep <port>`); if it's the user's, ask before stopping. Stop any you start when done. Never stop Docker stacks or systemd user units.
