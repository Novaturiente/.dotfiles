# Global Instructions (pi)

Never run sudo — ask user to run it. All dates/times in IST.

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
- Coolify (`coolify.eecglobal.com`) deploys `~/Projects/` apps — separate from local containers.

## Rules
1. Read everything task-related first. Clear → act. Ask only for: destructive/irreversible action, scope change, input only user has, real ambiguity. Never end turn on a promise.
2. Ask before building when request has >1 plausible reading, or touches production (auth, payments, DB schema, live data/routes). Otherwise build at 95% confidence. One `ask_user_question` call, ≤3 questions, recommended option first.
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
Open with one plain sentence (what happened / found). Then short bold headers + bullets, one fact each. Gloss every identifier in plain language on first mention. No process narration, no arrow chains, no invented jargon. Clear beats short.

## Coding style
- One unit, one job. Seams where change happens (data access, external services, UI, business rules). No single-implementation interfaces.
- Web basics: stateless handlers, work in DB (indexes, pagination), no N+1, slow work off request path.
- `~/Projects/` = Next.js/TS: render server-side where it helps SEO (public/marketing pages); client components only for interactivity. Colocate route code, lift to shared only at the second consumer. Validate with project's schema lib.

## Pi tool map
- Clarify → `ask_user_question`. Plan approval → `plan_mode_complete` (only when /plan active).
- MCP → pi built-in MCP (no `mcp` gateway tool). Servers: `extensions/project-mcp.ts` merges global `~/.pi/agent/mcp-global.json` with the nearest `.mcp.json` for repos under `~/Projects/`; same name → project wins. Never create `~/.pi/agent/mcp.json` (pi makes it beat project servers). Tools are `mcp__<server>__<tool>`, called from `codemode` scripts (find with `searchTools()`; server usage notes + tool list with `describeNamespace("serena")`). Exception: context7 has `direct` exposure, so call its tools directly. Status: footer `🔌 MCP: <servers> (<connected>)` from `extensions/mcp-status.ts`; details in `/mcp` (`pi mcp list` doesn't see extension servers). Symbol/caller/impact questions ("what calls X", "what breaks if X changes", "where is X defined") → `codegraph_*` tools, or Serena (`mcp__serena__find_symbol`, `mcp__serena__find_referencing_symbols`) via codemode, in main thread — never `scout` for these (no MCP tools, misses indirect callers). Text/config/dir-map questions → `scout` or grep. Library docs → context7 (`mcp__context7__resolve-library-id`, then `mcp__context7__query-docs`, called directly, not via codemode).
- Delegation is pre-authorized by the user: call `subagents_enable` and delegate without asking whenever a specialist fits or subtasks are independent; launch independent ones together, keep working meanwhile, correct any that drift. Pick narrowest agent: `scout` for recon, `worker` for bounded edits, `reviewer` for review. Still need an explicit request: multi-agent fan-outs (`/parallel-review`, `/review-loop`, `/parallel-research`, council) — they cost real money.
- Recon goes to `scout` (pinned to Haiku in settings, far cheaper than Opus main thread; keep it on Haiku, don't override its model up unless Haiku's summary proved insufficient), not main thread: any exploration spanning >3 files, dir/architecture mapping, "where/how is X done" text searches, reading long logs/docs. Ask it for a compact summary with file:line refs. Main thread reads only files it will edit or must quote. Exceptions: symbol questions (code-graph MCP above), one known file, whole-session-state repros.
- Noisy command output (tests, builds, lint, installs, `git log`/`diff`, logs) → filter at source: `2>&1 | tail -40`, or `2>&1 | grep -E "error|fail|warn" -i | head -50`, `git diff --stat` before full diff. Rerun unfiltered only when the filtered output isn't enough.
- Web → `pi_claude_code_provider_web_search`.
- Browser → native `agent_browser` tool (pi-agent-browser-native) only; never run `agent-browser` via bash, no browser MCP, no Playwright. Pass CLI args as a list: `{"args":["open","<url>"]}` → `["snapshot","-i"]` → `["click","@eN"]`/`["fill","@eN","text"]` → re-snapshot after page changes → `["close"]` when done. Fixed sequences → `batch --bail`; loops/branches → `agent_browser_code`; QA/Electron/extra tools → `agent_browser_tools`. Sessions are managed per pi session; use `sessionMode: "fresh"` for a clean launch (e.g. `--headed`). Localhost services reachable directly.
- Coolify → `coolify` skill. After any push from `~/Projects/`, follow its Post-Push Auto-Monitor unless user says skip.

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
