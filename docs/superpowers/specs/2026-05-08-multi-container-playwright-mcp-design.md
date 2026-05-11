# Multi-container Playwright MCP via host Chrome

**Date:** 2026-05-08
**Status:** Design approved, pending implementation plan
**Author:** brainstorming session
**Affects:** `bin/ai-run`, AGENTS.md template, OpenCode MCP config

## Problem

Playwright MCP needs a CDP endpoint to drive Chrome. macOS Chrome (Mach-O) cannot run inside a Linux container, so containers connect over CDP to a Chrome process running on the host. The user wants to run multiple containers concurrently, each driving its own visible Chrome window with its own profile.

The current implementation (commit `58a2d0e`) gives each container a unique port (`19222 + hash(container_name) % 100`), then writes that port back into the host's shared `~/.config/opencode/opencode.json` under a single key `mcp.playwright`. Because every container shares that one file, last-writer-wins: if container B starts after A, A's MCP config now points at B's Chrome port. The two designs — per-container port and per-key shared config — are incompatible.

## Goals

- Multiple containers can run concurrently, each driving its own host Chrome on its own CDP port.
- No mutation race on the shared OpenCode config file.
- Restarting a container reuses its existing Chrome window (warm tabs, warm profile).
- Stale entries from crashed/exited containers self-clean over time.
- Existing fallback to in-container Chromium when host Chrome is unavailable continues to work.

## Non-goals

- Per-container isolation of OpenCode config beyond the playwright section. Other settings remain shared.
- Hiding other containers' playwright entries from the agent. The agent in container A will see container B's MCP entry in the listed tools; it relies on an env-var pointer to know which is its own.
- Cross-host or remote-Chrome scenarios. This is local Docker Desktop on macOS.

## Design

### 1. Port assignment (unchanged)

`bin/ai-run` computes `HOST_CHROME_CDP_PORT = 19222 + (hash(CONTAINER_NAME) % 100)`. Deterministic per container name, which makes reuse possible.

### 2. Chrome lifecycle: reuse-if-alive

On container start, before launching Chrome:

1. Probe `http://localhost:$PORT/json/version` with a short timeout (~500ms).
2. If it responds with valid CDP JSON → reuse the existing Chrome.
3. Otherwise → launch a new Chrome:
   ```
   $CHROME_PATH \
     --remote-debugging-port=$PORT \
     --user-data-dir=$SANDBOX_DIR/chrome-profile-$PORT \
     --no-first-run \
     --no-default-browser-check &
   ```
   then poll the probe URL for up to 5 seconds.

Chrome is **not** killed on container exit. It outlives the container so the next run of the same container reuses warm tabs and profile state. The `--user-data-dir` is keyed by port, which (because the port is keyed by container name) effectively gives each container a stable profile directory.

If Chrome launch fails after the 5-second window, the existing fallback path activates: `HOST_CHROME_CDP=false`, the container falls back to in-container Chromium, and no MCP entry is registered for host Chrome.

### 3. Config mutation: locked sweep + append

The shared file `~/.config/opencode/opencode.json` is mutated by every container that boots. To prevent races, all mutations happen inside a single critical section guarded by `flock` on `~/.config/opencode/.playwright.lock`.

Inside the lock:

1. **Read** the current config (`jq` parse).
2. **Sweep**: for every key in `.mcp` matching `^playwright_.*`, probe its `--cdp-endpoint` with a 200 ms timeout. Drop entries whose probe fails.
3. **Append** this container's entry under key `playwright_<sanitized-container-name>_<port>` with value:
   ```json
   {
     "type": "local",
     "command": ["playwright-mcp", "--cdp-endpoint", "http://192.168.65.254:<port>"]
   }
   ```
4. **Atomic write**: `jq` to a temp file, then `mv` over the original.

`flock` is acquired with a 5-second timeout. If the lock cannot be obtained, the script logs a warning, skips the mutation, and continues. The container still runs; the agent will get a clear "MCP server not configured" failure if it tries to use Playwright. This is preferable to silently corrupting the config.

The MCP key uses both container name and port (rather than port alone) so entries remain readable in the config and so an admin pruning manually has unambiguous names.

The host port `192.168.65.254` is the Docker Desktop for Mac host-access address. This is unchanged from the existing code.

### 4. Container injection

`docker run` is augmented with two env vars:

```
-e PLAYWRIGHT_MCP_NAME=playwright_<sanitized-container-name>_<port>
-e PLAYWRIGHT_PORT=<port>
```

Inside the container, the AGENTS.md (or equivalent system-prompt source consumed by OpenCode) is templated at container startup to include one line:

> Your Playwright MCP server is named `${PLAYWRIGHT_MCP_NAME}`. Use it for browser automation. Do not invoke other `playwright_*` servers — they belong to other containers.

The exact mechanism (template substitution at image build time vs. on-startup script that appends to AGENTS.md inside `/home/agent`) is an implementation detail to be decided in the plan.

### 5. Removed code

The current racy block in `bin/ai-run` that does `jq '.mcp.playwright = {...}'` on the shared config is removed entirely. The new locked sweep+append replaces it.

## Failure modes

| Scenario | Behavior |
|---|---|
| Host Chrome launch fails | Fallback to container Chromium (existing path), no MCP entry registered. |
| `flock` timeout (>5s) | Skip mutation, log warning, container continues. Agent's Playwright calls will fail clearly. |
| `jq` missing | Skip MCP config entirely (existing behavior preserved). |
| Two containers same name | Docker disallows. Out of scope. |
| Stale entry whose port is reused by an unrelated process | Sweep probes `/json/version`; non-CDP processes will not respond with valid JSON. Treat invalid response as dead and remove. |
| Container crashes mid-flock | `flock` releases on process death. Next container acquires cleanly. |
| Sweep removes a live entry by mistake | Probe checks for valid CDP JSON in the response (not just HTTP 200), so non-Chrome processes on a recycled port don't masquerade as live entries. If a sweep does drop a live entry by mistake, the affected container's next start re-adds itself. |

## Testing

**Shell unit test** (`tests/playwright-mcp/sweep-append.sh`):
- Start two stub HTTP servers on distinct ports that respond 200 on `/json/version`.
- Pre-populate a config with one live and one dead `playwright_*` entry.
- Run the sweep+append logic with a third port.
- Assert: live entry preserved, dead entry removed, new entry added.

**Integration test** (manual or scripted):
- Launch two containers concurrently in two terminals.
- Verify both end up with distinct entries in `~/.config/opencode/opencode.json`.
- Verify each agent's Playwright tool drives its own Chrome window (visible inspection: open a unique URL in each, confirm windows differ).

**Lock contention test**:
- In a loop, launch 5 `bin/ai-run` invocations in the background, each adding a unique entry.
- After all complete, assert all 5 entries are present in the config (no lost writes).

## Open questions for the implementation plan

- AGENTS.md templating mechanism: build-time vs. runtime. Runtime (entrypoint script appends a line referencing `$PLAYWRIGHT_MCP_NAME`) is more flexible but couples MCP awareness to container startup ordering.
- Whether to expose a `bin/ai-run --prune-playwright` command for manual cleanup. Sweep-on-start handles the common case but a manual command is cheap insurance.
- Sanitization rule for container names in MCP keys (Docker permits `[a-zA-Z0-9][a-zA-Z0-9_.-]*`; OpenCode MCP keys may be stricter — verify and define a normalization).
