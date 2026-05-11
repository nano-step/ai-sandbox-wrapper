# TODO: Playwright MCP optimization (post-3.3.0)

Tracks follow-up work for the multi-container Playwright MCP feature
shipped in 3.3.0. Not blocking; here so we don't forget.

## Context

3.3.0 ships per-container `playwright_port_<port>` entries in the shared
`~/.config/opencode/opencode.json`, registered append-only under a lock
and swept on every container start. The design (`docs/superpowers/specs/2026-05-08-multi-container-playwright-mcp-design.md`)
chose option 3 — "agent sees all entries, no canonical" — to keep the
config logic simple.

That trades token cost: each running container's OpenCode loads tool
definitions for every `playwright_port_*` entry, even those belonging to
other containers it shouldn't use. Ten concurrent containers ≈ ten times
the playwright tool surface in every agent's context.

## Y. Cleanup-on-exit (small, ~20 lines)

**Problem:** Stale entries accumulate when containers exit and no new
container ever launches (sweep-on-start fires only at launch).

**Approach:** Add a `trap` in `bin/ai-run` after the host-Chrome block
so that when `docker run` returns (container exited), we:

1. Acquire the `~/.config/opencode/.playwright.lock` lock.
2. Probe our own port — if still alive (e.g. another container shares
   the deterministic port), skip removal.
3. Otherwise `jq del(.mcp[$name])` for this container's
   `PLAYWRIGHT_MCP_NAME`.

**Caveats:**
- Trap doesn't fire on `kill -9` or host reboot. The existing
  sweep-on-start path remains the safety net.
- Probe-before-remove is important so that one container exiting
  doesn't yank the entry another live container is using.

## X. Per-container effective config (medium, ~40 lines)

**Problem:** Even live entries bloat tokens — every container sees all
`playwright_port_*` entries in the shared config.

**Approach:** On launch, materialize
`$SANDBOX_DIR/containers/<name>/opencode.json` by:

1. Reading the host's `~/.config/opencode/opencode.json`.
2. Stripping all keys matching `playwright_port_*` from `.mcp`.
3. Adding exactly this container's `playwright_port_<port>` entry (or
   renaming it to plain `playwright` for cleanliness; agent's
   `PLAYWRIGHT_MCP_NAME` env var would change accordingly).
4. Preserving every other MCP server and setting from the host file.

Then override the existing bind mount of the host file with this
per-container file:

```
-v $SANDBOX_DIR/containers/<name>/opencode.json:/home/agent/.config/opencode/opencode.json:ro
```

The host's shared config keeps its sweep+append entries for visibility
and admin/cleanup tools, but containers never read it directly.

**Caveats:**
- Diverges from "single source of truth." Need to refresh per-container
  config when host config changes mid-session (probably acceptable to
  ignore — config changes typically need a restart anyway).
- Cleanup of the per-container files needs its own sweep (delete dirs
  for containers no longer running). Tie into Y's trap and/or
  sweep-on-start.

**A previous WIP attempt at this approach is preserved in a stash on
the main checkout** (`pre-merge: abandoned container-specific MCP
config WIP + unrelated dockerfile/setup edits`) — worth reviewing for
ideas, though the heredoc was buggy.

## Order

Do **Y first** — small, isolated, immediate hygiene win.
Then **X** — bigger refactor, real token savings.

## Tests

- Y: unit test that simulated trap path removes the entry, and that a
  probe-alive entry is *not* removed.
- X: integration-ish test that mounts a per-container config and
  verifies the container's `opencode.json` contains only its own
  playwright entry while the host file has all of them.
