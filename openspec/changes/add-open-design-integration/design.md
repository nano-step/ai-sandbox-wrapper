## Context

ai-sandbox-wrapper today wraps **ephemeral CLI tools** (claude, opencode, gemini, codex, …). Each `ai-run <tool>` does `docker run -it --rm` — container lives for one user session, then dies.

open-design is fundamentally different: it's a **long-running HTTP daemon** (Node.js + Express on port 7456) backed by SQLite + filesystem state in `.od/`. It must outlive any single agent session because multiple agents may use it serially or in parallel, and project history must persist.

This change is the first time the wrapper supports a service-style tool, so the design must establish a sustainable pattern (not a one-off hack), because future tools (MCP servers, vector DBs, sandboxed browsers) will need the same shape.

### Existing constraints

- `bin/ai-run` is a single bash script with a flag-parsing loop (lines 13–32, per `AGENTS.md`)
- Tools install themselves via `lib/install-{tool}.sh` writing a `dockerfiles/{tool}/Dockerfile`
- `~/.ai-sandbox/env` already exists for API keys and is mounted into every tool container
- Containers run as non-root user `agent` (UID 1001) with `CAP_DROP=ALL`
- No tool today uses Docker networks or volumes (everything is `--rm` ephemeral)

### Upstream constraints (open-design)

Per librarian investigation of [`nexu-io/open-design@6bf865a`](https://github.com/nexu-io/open-design):

- Daemon supports bearer-token auth via `OD_API_TOKEN` env var when `OD_BIND_HOST != localhost`
- SSE streaming on `/api/chat`, JSON on most other routes
- Multi-project isolation built in (`project_id` in every request)
- Health endpoint `/api/health` is unauthenticated (good for status checks)
- CORS validation enforced via `extraAllowedOrigins`, but loopback always allowed (irrelevant in-network)

## Goals / Non-Goals

### Goals

1. **Zero-friction setup**: After one-time `init`, user types `ai-run open-design start` and `ai-run opencode` — done. No env exports, no port mapping decisions, no network surgery.
2. **One daemon, many agents (Mode A)**: A single `ai-open-design` container serves N concurrent agent containers, each issuing requests with a `project_id` it created.
3. **Persistent token**: Same `OD_API_TOKEN` across daemon restarts, agent container restarts, system reboots — until user deletes it.
4. **Sandbox-philosophy aligned**: Default deny — daemon not reachable from host unless `--expose` is explicit; read-only artifact access for agents.
5. **Survives mismatch in lifetime**: Agent container started **before** daemon → agent's env still has correct `$OD_API_TOKEN` (loaded from mounted file at shell start); `$OD_DAEMON_URL` resolves once daemon comes up. No agent restart needed.

### Non-Goals

- Building a typed client library for open-design API (raw curl is fine for Phase 1; MCP wrapper deferred)
- Supporting Mode B (1-1 pairing per session) — not asked for, increases complexity
- Multi-host or remote daemon support — single host only
- Migrating other tools (claude, gemini, …) to be daemons — they're CLIs, that's fine
- Supporting non-Docker container runtimes (Podman, containerd) — out of scope for this change

## Decisions

### Decision 1: Long-running daemon container with persistent name

`docker run -d --name ai-open-design --restart unless-stopped --network ai-sandbox ai-open-design:latest`

- `--name ai-open-design` makes it addressable via Docker DNS from other containers in the same network as `http://ai-open-design:7456`
- `--restart unless-stopped` makes it survive host reboots; user-initiated stops are honored
- No `-p 7456:7456` by default → host has zero exposure of the daemon

**Alternative considered**: Use docker-compose. Rejected because the wrapper deliberately avoids requiring compose (per `AGENTS.md`, all tools use plain `docker run`); compose would introduce a new dependency and a new mental model.

### Decision 2: Custom Docker network `ai-sandbox`, not `host.docker.internal`

The daemon listens only on the internal network. All agent containers (existing and new) join `ai-sandbox` on start.

- ✅ Cross-platform (works on Linux containers, not just Docker Desktop)
- ✅ No host port pollution
- ✅ Service discovery via container name
- ✅ No conflict if user later wants multi-instance (different networks per pair)

**Alternative considered**: Publish 7456 to host and use `host.docker.internal`. Rejected: not native on Linux containers, requires `--add-host` workaround, leaks port to host machine, breaks sandbox philosophy.

### Decision 3: Token persistence in `~/.ai-sandbox/env` (Hybrid model)

`init` subcommand:
1. If `$OD_API_TOKEN` already set in `~/.ai-sandbox/env` → use it (idempotent)
2. Else `openssl rand -hex 32` → write `OD_API_TOKEN=<value>` to `~/.ai-sandbox/env`
3. Also write `OD_DAEMON_URL=http://ai-open-design:7456` to same file

`start` subcommand reads `~/.ai-sandbox/env`, passes `OD_API_TOKEN` to daemon container via `-e OD_API_TOKEN`.

Agent containers already mount `~/.ai-sandbox/env` (existing behavior) → env vars available at shell start.

- ✅ Single source of truth, already in the trust boundary for API keys
- ✅ User can override token manually by editing the file
- ✅ Token survives daemon restart, container rebuild, system reboot

**Alternative considered**: Separate `~/.ai-sandbox/open-design/token` file. Rejected: doubles the source-of-truth surface, no benefit since env file already exists.

### Decision 4: Default network membership for all containers via `ai-run`

`bin/ai-run` is modified so every `docker run` invocation includes `--network ai-sandbox`. Network is created lazily on first use:

```bash
ensure_network() {
  docker network inspect ai-sandbox >/dev/null 2>&1 || \
    docker network create ai-sandbox >/dev/null
}
```

- ✅ Existing tools (opencode, claude, …) keep working — network membership is transparent
- ✅ When user later runs `open-design start`, the daemon joins the same network and is immediately reachable from running agent containers (no agent restart)
- ✅ No conflict with `--network host` users (advanced flag overrides default)

**Alternative considered**: Only join network when `--link open-design` is passed. Rejected: forces user to plan ahead, defeats the "morning don't need OD, afternoon do, no restart" requirement.

### Decision 5: Read-only artifact volume mount for agents

Daemon container mounts named volume `ai-open-design-data` at `/app/.od` (read-write, owned by daemon).

Agent containers mount same volume at `/workspace/.od` **read-only**.

- Agents can read generated HTML/artifacts directly from filesystem (faster than HTTP for large files)
- Agents cannot corrupt SQLite or other daemon state
- Volume managed by Docker, lives independent of any container

**Alternative considered**: Bind-mount to `~/.ai-sandbox/tools/open-design/data` on host. Rejected: Docker volume is cleaner, no host-path quirks across macOS/Linux/WSL.

### Decision 6: `od-status` / `od-health` helper binaries in base image

Tiny bash scripts installed at `/usr/local/bin/od-status` and `/usr/local/bin/od-health`:

```bash
# /usr/local/bin/od-health
#!/usr/bin/env bash
curl -sf -H "Authorization: Bearer ${OD_API_TOKEN:-}" \
  "${OD_DAEMON_URL:-http://ai-open-design:7456}/api/health"
```

- Lets any agent (or user via `docker exec`) run a sanity check
- Surfaces the contract to agents (`od-status` in PATH → discoverable)
- Adds <1KB to base image

**Alternative considered**: Ship an `od` CLI that wraps full API. Rejected: scope creep; can come in Phase 2 as MCP wrapper or dedicated CLI.

### Decision 7: Backward compatibility with no-network mode

Some users might have automation that does `docker run` directly bypassing `ai-run`. We don't break them. The network is opt-in via `ai-run`; manual `docker run` still works as before (just without auto-network join).

We also ensure `~/.ai-sandbox/env` only **appends** `OD_API_TOKEN` and `OD_DAEMON_URL` — never rewrites existing lines.

## Risks / Trade-offs

### Risk 1: Daemon image bloat

The upstream `vanjayak/open-design:latest` is large (Node 24 runtime, full daemon, embedded skills + design systems). Mitigation:
- Document expected pull size in installer output (~500 MB)
- Pin to specific tag (configurable via `OPEN_DESIGN_IMAGE` env, default `vanjayak/open-design:latest`)
- Allow user override via `--image` flag on `ai-run open-design start` for custom builds

### Risk 2: Token leak via env file

`~/.ai-sandbox/env` is world-readable on some systems if user misconfigures umask. Mitigation:
- `init` subcommand chmods file to `600` after write
- Document the trust boundary in README

### Risk 3: Volume permission issues across macOS/Linux

Named volumes work cross-platform, but file ownership inside the volume may differ from agent UID 1001. Mitigation:
- Daemon container runs as same UID (1001) where possible (verify with upstream image)
- If upstream image uses different UID, document workaround (`chown` step in install script) or wrap in init container

### Risk 4: `restart unless-stopped` keeps daemon running after user thinks they stopped

User runs `ai-run open-design stop` then reboots — daemon comes back up because `restart=unless-stopped` is "honored stop". This is correct Docker behavior, but easy to confuse. Mitigation:
- `stop` subcommand uses `docker stop` (sets stopped state, daemon stays down across reboots)
- Document this in `--help`

### Risk 5: Multiple `init` runs overwrite token

User accidentally `init` twice → wipes token → existing agent containers have stale token. Mitigation:
- `init` is idempotent: if `OD_API_TOKEN` already in `~/.ai-sandbox/env`, do nothing unless `--force`
- `--force` prompts for confirmation

### Risk 6: Upstream API drift

`nexu-io/open-design` is in active development (0.8.0-preview); API may change. Mitigation:
- Pin daemon image tag in install script (not `latest`)
- Helper script `od-health` only relies on `/api/health` (most stable endpoint)
- Phase 2 MCP wrapper will provide an abstraction layer

### Trade-off: Mode A only (no Mode B in this change)

Mode A (shared daemon) is shipped; Mode B (1-1 pairing) is deferred. Trade-off: users who want per-session isolation must wait for a future change. Acceptable because:
- Mode A covers the stated use case ("OpenCode controls open-design")
- Mode A is strictly easier to implement
- Adding Mode B later is non-breaking (new flag, new dispatcher branch)

## Migration Plan

This is a new feature, no migration of existing config or data needed.

For users who already have ai-sandbox-wrapper installed:

1. Pull latest, rebuild base image (`bash lib/install-base.sh`) — adds `od-status`/`od-health` to PATH inside all future containers
2. Install open-design tool: `bash lib/install-open-design.sh`
3. One-time init: `ai-run open-design init`
4. Existing OpenCode/Claude containers: stop and re-run via `ai-run` to join the new network. Containers started via `docker run` directly are unaffected and continue to work without open-design connectivity.

## Open Questions

None blocking implementation. Future considerations (Phase 2):

- Should we ship an MCP server inside the daemon image so OpenCode can use it as a native tool instead of curl?
- Should `od-status` parse the daemon's structured status and pretty-print, or stay minimal?
- Multi-instance / per-feature pairing (Mode B) — wait for user demand before implementing.
