# Coolify API reference

Base: `$COOLIFY_URL/api/v1`. Every path below is what you pass to
`coolify.sh <METHOD> <path> [body]`. Verified against Coolify 4.1.2.

## Creating resources

All create calls need the same three locators. Look them up first:

```bash
S=~/.jcode/skills/coolify/coolify.sh
$S GET /projects                          # → project uuid
$S GET /projects/PROJECT_UUID/environments  # → environment name + uuid
$S GET /servers                           # → server uuid
```

`project_uuid` and `server_uuid` are required, plus at least one of
`environment_name` or `environment_uuid` (4.1.2 accepts either; newer versions
want both, so sending both is safest).

**Application from a public git repo**

```bash
$S POST /applications/public '{
  "project_uuid": "...", "server_uuid": "...",
  "environment_name": "production", "environment_uuid": "...",
  "git_repository": "https://github.com/owner/repo",
  "git_branch": "main",
  "build_pack": "nixpacks",
  "name": "my-app",
  "domains": "https://app.example.com",
  "ports_exposes": "3000",
  "instant_deploy": true
}'
```

`build_pack` is one of `nixpacks`, `static`, `dockerfile`, `dockercompose`.

**Other application sources** — same locators, plus:

| Path | Extra required |
| --- | --- |
| `POST /applications/private-github-app` | `github_app_uuid`, `git_repository`, `git_branch`, `build_pack` |
| `POST /applications/private-deploy-key` | `private_key_uuid`, `git_repository`, `git_branch`, `build_pack` |
| `POST /applications/dockerfile` | `dockerfile` (raw contents) |
| `POST /applications/dockerimage` | `docker_registry_image_name`, optional `docker_registry_image_tag` |

Supporting lookups: `GET /github-apps`, `GET /security/keys` (private keys).

**Service from Coolify's catalog**

```bash
$S POST /services '{
  "project_uuid": "...", "server_uuid": "...",
  "environment_name": "production", "environment_uuid": "...",
  "type": "plausible", "name": "analytics", "instant_deploy": true
}'
```

**Database**

```bash
$S POST /databases/postgresql '{
  "project_uuid": "...", "server_uuid": "...",
  "environment_name": "production", "environment_uuid": "...",
  "name": "app-db", "postgres_user": "app", "postgres_db": "app"
}'
```

Engines: `postgresql`, `mysql`, `mariadb`, `mongodb`, `redis`, `keydb`,
`dragonfly`, `clickhouse`.

**Project / environment**

```bash
$S POST /projects '{"name":"My Project","description":"..."}'
$S POST /projects/PROJECT_UUID/environments '{"name":"staging"}'
```

## Endpoint catalog

`{uuid}` is the resource UUID shown by `coolify.sh find`.

**Applications**

```
GET    /applications
GET    /applications/{uuid}
PATCH  /applications/{uuid}
DELETE /applications/{uuid}
POST   /applications/{uuid}/start | /stop | /restart
GET    /applications/{uuid}/logs?lines=N
GET    /applications/{uuid}/envs
POST   /applications/{uuid}/envs
PATCH  /applications/{uuid}/envs
PATCH  /applications/{uuid}/envs/bulk
DELETE /applications/{uuid}/envs/{env_uuid}
GET    /applications/{uuid}/storages
POST   /applications/{uuid}/storages
PATCH  /applications/{uuid}/storages
DELETE /applications/{uuid}/storages/{storage_uuid}
GET    /applications/{uuid}/scheduled-tasks
POST   /applications/{uuid}/scheduled-tasks
PATCH  /applications/{uuid}/scheduled-tasks/{task_uuid}
DELETE /applications/{uuid}/scheduled-tasks/{task_uuid}
GET    /applications/{uuid}/scheduled-tasks/{task_uuid}/executions
DELETE /applications/{uuid}/previews/{pull_request_id}
```

**Deployments**

```
GET    /deploy?uuid=A,B&force=true        also accepts ?tag=NAME
GET    /deployments                       currently running
GET    /deployments/{deployment_uuid}     one deployment, includes logs
GET    /deployments/applications/{uuid}   history for one application
POST   /deployments/{deployment_uuid}/cancel
```

Deployment `status`: `queued`, `in_progress`, `finished`, `failed`,
`cancelled_by_user`.

**Services**

```
GET    /services
POST   /services
GET|PATCH|DELETE /services/{uuid}
POST   /services/{uuid}/start | /stop | /restart
GET    /services/{uuid}/envs                   (+ POST, PATCH, /bulk, DELETE /{env_uuid})
GET    /services/{uuid}/storages | /scheduled-tasks
```

Not on 4.1.2 (404, newer Coolify only): `/services/{uuid}/logs`,
`/services/{uuid}/applications`, `/services/{uuid}/databases` and the
per-container start/stop/restart under them.

**Databases**

```
GET    /databases
GET|PATCH|DELETE /databases/{uuid}
POST   /databases/{uuid}/start | /stop | /restart
GET    /databases/{uuid}/envs                  (+ POST, PATCH, /bulk, DELETE)
GET    /databases/{uuid}/backups
POST   /databases/{uuid}/backups
PATCH  /databases/{uuid}/backups/{scheduled_backup_uuid}
DELETE /databases/{uuid}/backups/{scheduled_backup_uuid}
GET    /databases/{uuid}/backups/{scheduled_backup_uuid}/executions
```

`/databases/{uuid}/logs` is not on 4.1.2 either.

Every path in this file was probed against the live instance with a fake uuid:
a `"... not found"` message means the route exists, a bare `"Not found."` with
a docs link means it does not. Anything that 404'd as a route has been removed
from the lists above.

**Servers, projects, infrastructure**

```
GET    /servers
GET|PATCH|DELETE /servers/{uuid}
GET    /servers/{uuid}/resources          everything running on that server
GET    /servers/{uuid}/domains
GET    /projects
POST   /projects
GET|PATCH|DELETE /projects/{uuid}
GET    /projects/{uuid}/environments
POST   /projects/{uuid}/environments
GET    /projects/{uuid}/{environment_name_or_uuid}
GET    /resources                         every resource, all projects
GET    /security/keys                     private keys (+ POST, PATCH, DELETE)
GET    /github-apps
GET    /github-apps/{id}/repositories
GET    /teams | /teams/current | /teams/current/members
GET    /version | /health
```

## Application fields for PATCH

Read current values with `coolify.sh get /applications/{uuid} <keys...>`;
`PATCH` only the keys you change.

Identity and routing: `name`, `description`, `fqdn`, `redirect`,
`ports_exposes`, `ports_mappings`, `custom_network_aliases`.

Source: `git_repository`, `git_branch`, `git_commit_sha`, `watch_paths`,
`private_key_id`, `source_id`.

Build: `build_pack`, `base_directory`, `publish_directory`, `install_command`,
`build_command`, `start_command`, `dockerfile`, `dockerfile_location`,
`dockerfile_target_build`, `docker_compose_location`, `docker_compose_raw`,
`docker_registry_image_name`, `docker_registry_image_tag`, `static_image`,
`custom_nginx_configuration`.

Health check: `health_check_enabled`, `health_check_path`, `health_check_port`,
`health_check_host`, `health_check_scheme`, `health_check_method`,
`health_check_return_code`, `health_check_response_text`,
`health_check_interval`, `health_check_timeout`, `health_check_retries`,
`health_check_start_period`.

Limits: `limits_memory`, `limits_memory_swap`, `limits_memory_reservation`,
`limits_cpus`, `limits_cpuset`, `limits_cpu_shares`.

Hooks and extras: `pre_deployment_command`, `pre_deployment_command_container`,
`post_deployment_command`, `post_deployment_command_container`,
`custom_docker_run_options`, `custom_labels`, `manual_webhook_secret_github`,
`is_http_basic_auth_enabled`, `http_basic_auth_username`,
`http_basic_auth_password`, `swarm_replicas`, `max_restart_count`.
