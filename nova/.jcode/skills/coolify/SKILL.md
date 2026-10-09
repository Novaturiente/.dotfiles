---
name: coolify
description: Manage Coolify (self-hosted PaaS) over its REST API — list applications/services/databases, check status, deploy or redeploy, watch a deployment to completion, read build and container logs, edit environment variables and settings, start/stop/restart, and create new resources. Use whenever the user mentions Coolify, asks to deploy or redeploy an app, check whether a deploy succeeded, look at deploy logs, change env vars on a hosted app, or after pushing code to a repo that Coolify deploys.
---

# Coolify

Instance: `$COOLIFY_URL` (Coolify 4.1.2). Credentials live in `~/.env` as
`COOLIFY_URL` and `COOLIFY_API_KEY`; the wrapper reads them itself, so never
print, echo, or inline the token.

## The wrapper

All calls go through `~/.jcode/skills/coolify/coolify.sh`. It handles auth,
pretty-prints JSON, and exits non-zero on HTTP >= 400.

```bash
S=~/.jcode/skills/coolify/coolify.sh

$S GET   /applications                      # raw API call, any method
$S PATCH /applications/UUID '{"name":"x"}'  # third arg is the JSON body
$S get   /applications/UUID fqdn git_branch # print only the keys you name
$S envs  /applications/UUID                 # env var names + uuids, no values
$S find  learning                           # uuid + status by name/domain/repo
$S latest APP_UUID                          # newest deployment uuid + status
$S watch DEPLOYMENT_UUID [timeout_sec]      # poll until finished/failed
$S watch-app APP_UUID [timeout_sec]         # wait for a webhook deploy, then watch
$S logs  DEPLOYMENT_UUID [tail_lines]       # build log lines
```

Resource lists are large (38 resources here). Start with `find` — one
`/resources` call, one line per match — so the full inventory never lands in
context. It covers applications, services and databases at once; the type
column reads `application`, `service`, or `standalone-postgresql` and friends.

## Recipes

**Status of one resource**

```bash
$S find eec-learning                        # → uuid + "running:healthy"
$S get /applications/UUID status fqdn git_branch last_online_at
```

An application's JSON has ~100 keys, so prefer `get` with the keys you care
about; fall back to `GET /applications/UUID` only when you need to browse.

Status strings look like `running:healthy`, `running:unknown`,
`degraded:unhealthy`, `exited:unhealthy`. The part after the colon is the
Docker healthcheck; `unknown` means no healthcheck is configured, not a fault.

**Deploy / redeploy**

```bash
$S GET '/deploy?uuid=APP_UUID'              # returns deployment_uuid
$S GET '/deploy?uuid=APP_UUID&force=true'   # force=true skips the build cache
$S GET '/deploy?tag=TAG'                    # deploy everything with a tag
```

`uuid` accepts a comma-separated list. Coolify 4.1.2 accepts this as `GET`;
newer versions expose it as `POST /deploy` with the same query parameters.
Then watch it:

```bash
$S watch DEPLOYMENT_UUID
```

`watch` polls every 10s, returns 0 on `finished`, and on failure prints the
last 40 build log lines to stderr and returns 1. Default timeout is 540s, just
under the Bash tool's 600s cap — for a build known to run longer, pass a bigger
timeout and run the command in the background rather than blocking the tool.

**Deployment history**

```bash
$S latest APP_UUID                          # newest deployment for one app
$S GET /deployments                         # in-flight deployments, all apps
$S GET /deployments/applications/APP_UUID   # full history for one app
$S GET /deployments/DEPLOYMENT_UUID         # one deployment, build log included
$S POST /deployments/DEPLOYMENT_UUID/cancel
```

**Runtime logs** (container output, not build output)

```bash
$S GET '/applications/UUID/logs?lines=100'
```

Applications only on 4.1.2 — `/services/UUID/logs` and `/databases/UUID/logs`
return 404 here; they exist in newer Coolify. For a service or database, read
the container log over SSH on the server instead.

**Lifecycle**

```bash
$S POST /applications/UUID/restart
$S POST /applications/UUID/stop
$S POST /applications/UUID/start
```

Same three verbs exist under `/services/UUID/` and `/databases/UUID/`. This
instance also accepts `GET` on these paths, but use `POST` — newer Coolify
versions drop the `GET` form.

**Environment variables**

```bash
$S envs /applications/UUID          # names + env uuids, values never printed
$S POST /applications/UUID/envs   '{"key":"API_URL","value":"https://x","is_preview":false}'
$S PATCH /applications/UUID/envs  '{"key":"API_URL","value":"https://y"}'
$S PATCH /applications/UUID/envs/bulk '{"data":[{"key":"A","value":"1"},{"key":"B","value":"2"}]}'
$S DELETE /applications/UUID/envs/ENV_UUID
```

`PATCH .../envs` matches by `key`; `DELETE` needs the env var's own uuid, which
`envs` prints. Use `envs`, not `GET /applications/UUID/envs` — the raw call
dumps every secret value into the transcript (66 of them on one app here).
Reach for the raw call only when the user asks for a specific value.

Env changes only take effect on the next deployment — redeploy after editing.
Same paths work for `/services/UUID/envs` and `/databases/UUID/envs`.

**Settings / configuration**

```bash
$S PATCH /applications/UUID '{"fqdn":"https://app.example.com","build_pack":"nixpacks"}'
```

`PATCH` is a partial update — send only the keys you change. Read the current
values first with `$S get /applications/UUID <keys...>`. Commonly edited keys:
`name`, `fqdn`, `git_branch`, `build_pack`, `base_directory`, `publish_directory`,
`install_command`, `build_command`, `start_command`, `ports_exposes`,
`ports_mappings`, `health_check_enabled`, `health_check_path`, `limits_memory`,
`limits_cpus`, `pre_deployment_command`, `post_deployment_command`,
`watch_paths`, `redirect`. See `reference.md` for the full field list.

**Creating resources** — see `reference.md`. Creation needs `project_uuid`,
`server_uuid`, and an environment name or uuid, all looked up first.

## Post-Push Auto-Monitor

After any `git push` from a repo under `~/Projects/`, Coolify's webhook starts
a deployment on its own.

**In jcode this is automatic.** The `pre_tool`/`post_tool` hooks in
`~/.jcode/hooks/` detect the push and start `coolify-watch-deploy.sh` in the
background. The push's tool output then ends with
`[coolify] monitoring deployment for <repo>; log: <path>`. Do not start a
second watcher. Wait for the deploy with
`bash` + `run_in_background` running `tail --pid=$(pgrep -f "coolify-watch-deploy.sh <repo_dir>" | head -1) -f <log path>`
(or just read the log after a few minutes), then report as below.

Only when that line is missing (push ran outside `~/Projects`, or the hook
failed) watch it by hand:

```bash
S=~/.jcode/skills/coolify/coolify.sh
$S find "$(git remote get-url origin | sed -E 's#\.git$##; s#.*[:/]([^/]+/[^/]+)$#\1#')"
```

When several applications share one repo, pick the one whose `git_branch`
matches the branch you pushed (`$S get /applications/UUID git_branch`). Then:

```bash
$S watch-app APP_UUID
```

`watch-app` waits up to 60s for the webhook deployment to appear, then watches
it to completion. It returns 1 and says so if no deployment starts, which
usually means the branch you pushed is not the deployed one or the webhook is
not wired up.

Report the final status in one line. On failure, quote the shortest decisive
log line rather than the whole log. Skip all of this if the user says "skip
coolify check" or similar.

## Safety

- `DELETE` on an application, service, database, project, or server is
  irreversible and takes containers and volumes with it. Confirm with the user
  before any `DELETE`, and name what will be destroyed.
- Deploying, restarting, and stopping cause user-visible downtime. Fine to run
  when asked; ask first when you inferred the need yourself.
- Never write the API token into a file, a command echo, or a commit.
- Environment variable values are live production secrets. Read them with
  `envs` (names only) unless the user asked for a specific value, and never
  paste one into a file, a commit, or an outbound message.
