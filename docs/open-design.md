# Open Design Integration

[`nexu-io/open-design`](https://github.com/nexu-io/open-design) is an open-source, agent-native design tool that generates HTML prototypes, dashboards, and landing pages from natural language. This integration gives any sandboxed agent (OpenCode, Claude, Codex, ...) a direct path to the open-design daemon via `$OD_DAEMON_URL` and `$OD_API_TOKEN`, injected automatically. No manual Docker juggling, no port exposure by default.

## Prerequisites

- Docker installed and running
- ai-sandbox-wrapper base image built: `bash lib/install-base.sh`
- open-design image built: `bash lib/install-open-design.sh` (see Quick Start)
- Optional: a model provider API key in `~/.ai-sandbox/env` (open-design needs one to generate designs)

## Quick Start

```bash
# 1. Build image (once)
bash lib/install-open-design.sh

# 2. Initialize (once): generates token, creates network + volume
ai-run open-design init

# 3. Start daemon (background, survives reboots)
ai-run open-design start

# 4. Verify
ai-run open-design status

# 5. Launch any agent — it connects automatically
ai-run opencode
```

Inside the agent container, the daemon is immediately reachable:

```bash
# Inside opencode shell
od-health          # GET /api/health (unauthenticated)
od-status          # shows URL, masked token, health result
```

## Lifecycle Commands

### `ai-run open-design init [--force]`

One-time setup. Generates a 256-bit random bearer token, writes `OD_API_TOKEN` and `OD_DAEMON_URL` to `~/.ai-sandbox/env`, creates the Docker network `ai-sandbox` (if missing), and creates the volume `ai-open-design-data`.

Idempotent: if `OD_API_TOKEN` already exists in `~/.ai-sandbox/env`, it does nothing. Use `--force` to regenerate the token (prompts for confirmation).

```
🔑 Generating API token...
🌐 Creating network ai-sandbox...
💾 Creating volume ai-open-design-data...
✅ Done. Run: ai-run open-design start
```

### `ai-run open-design start [--expose] [--port N]`

Boots the daemon container in detached mode on the `ai-sandbox` network.

```bash
ai-run open-design start              # internal only (default, recommended)
ai-run open-design start --expose     # also publishes port 7456 to host
ai-run open-design start --expose --port 17456  # custom host port
```

The daemon uses `--restart unless-stopped`, so it comes back after host reboots. A user-initiated `ai-run open-design stop` honors the stopped state.

### `ai-run open-design stop`

Stops the daemon container. Data in `ai-open-design-data` is preserved. You can restart with the same or different flags.

```bash
ai-run open-design stop
# ✅ Stopped ai-open-design
```

### `ai-run open-design restart [start-flags...]`

Convenience: stop followed by start. Passes through any flags accepted by `start`.

```bash
ai-run open-design restart --expose --port 17456
```

### `ai-run open-design status`

Shows container state, network, port bindings, token presence (masked), and daemon health.

```
Container:  ai-open-design (running)
Network:    ai-sandbox
Port:       internal only
Token:      OD_API_TOKEN=****...ef3a
Health:     {"status":"ok","version":"0.8.0-preview"}
```

### `ai-run open-design logs [-f|--follow]`

Pass-through to `docker logs`:

```bash
ai-run open-design logs          # recent output
ai-run open-design logs -f       # follow (stream)
```

## Calling the API from an Agent Container

Every agent container launched via `ai-run` has `$OD_DAEMON_URL` and `$OD_API_TOKEN` in its environment (loaded from `~/.ai-sandbox/env` at shell start).

```bash
# 1. Health check (no auth required)
curl -sf "$OD_DAEMON_URL/api/health"
# {"status":"ok","version":"0.8.0-preview"}

# 2. List projects
curl -sf -H "Authorization: Bearer $OD_API_TOKEN" \
  "$OD_DAEMON_URL/api/projects"

# 3. Create a project
curl -sf -X POST -H "Authorization: Bearer $OD_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"my-dashboard"}' \
  "$OD_DAEMON_URL/api/projects"
# {"project_id":"proj_abc123","name":"my-dashboard"}

# 4. Start a chat (SSE streaming — note -N flag)
curl -N -H "Authorization: Bearer $OD_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project_id":"proj_abc123","message":"Create a dark dashboard with sales metrics"}' \
  "$OD_DAEMON_URL/api/chat" | head -20
# data: {"type":"thinking","content":"..."}
# data: {"type":"artifact","path":".od/proj_abc123/index.html"}
# ...
```

Generated artifacts are also available directly via the read-only volume mounted at `/workspace/.od`:

```bash
ls /workspace/.od/proj_abc123/
# index.html  assets/  ...

cat /workspace/.od/proj_abc123/index.html
```

Reading from the volume is faster than HTTP for large files and doesn't require auth.

## Mode A: One daemon, many agents

This release ships Mode A only. One `ai-open-design` container serves all agent containers simultaneously. Each agent creates its own `project_id` via the API to isolate its work. Agents can run in parallel; the daemon handles concurrent requests.

Mode B (1-1 daemon-per-session pairing) is on the roadmap but not in this release.

## Troubleshooting

### "OD_API_TOKEN not found"

You haven't run `ai-run open-design init`. Run it.

### "image 'ai-open-design:latest' not built"

Run `bash lib/install-open-design.sh`. Expect ~500 MB on first pull.

### `od-health` returns "daemon unreachable"

- Daemon not running? Check with `ai-run open-design status`.
- Agent container started before daemon? That's fine — env vars stay valid. Start the daemon, then re-run `od-health` inside the container.
- Container joined a different network? Inspect with `docker network inspect ai-sandbox` to confirm both containers are members.

### Daemon won't start: port conflict

Something else is using port 7456. Pick a different host port:

```bash
ai-run open-design start --expose --port 17456
```

(Only relevant when using `--expose`. Internal-only mode has no host port.)

### Token leaked / need to rotate

```bash
ai-run open-design init --force   # prompts for confirmation
```

After rotation: restart the daemon, then stop and re-run any agent containers that had the old token loaded.

### Remove all data

```bash
ai-run open-design stop
docker rm ai-open-design
docker volume rm ai-open-design-data
sed -i '/^OD_API_TOKEN=/d; /^OD_DAEMON_URL=/d' ~/.ai-sandbox/env
```

## How it works

```
HOST
  ~/.ai-sandbox/env  (OD_API_TOKEN, OD_DAEMON_URL)
        |
        | mounted read-only
        v
┌─────────────────────────────────────────────────┐
│              Docker network: ai-sandbox          │
│                                                  │
│  ai-open-design:7456  ←── ai-sandbox-opencode   │
│  (daemon, R/W volume)      (agent, RO volume)   │
│                                                  │
│  /workspace/.od  (read-only artifact access)    │
└─────────────────────────────────────────────────┘
```

The `ai-sandbox` Docker network provides service discovery: agents reach the daemon at `http://ai-open-design:7456` by container name, with no host port required. The token in `~/.ai-sandbox/env` is the shared secret, living in the same trust boundary as other API keys. The named volume `ai-open-design-data` gives agents read-only access to generated artifacts without making HTTP calls.

For full rationale on each design decision, see `openspec/changes/add-open-design-integration/design.md`.

## Roadmap

- **Phase 2**: MCP server wrapper so agents call open-design as a native tool (no curl)
- **Phase 3**: Mode B (1-1 daemon per OpenCode session) for per-session isolation
- **Phase 4**: `od-connect` interactive helper for ad-hoc wiring

## Links

- OpenSpec proposal: `openspec/changes/add-open-design-integration/`
- Upstream: https://github.com/nexu-io/open-design
- GitHub issue: nano-step/ai-sandbox-wrapper#11
