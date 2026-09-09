## Context

The `ai-run` script manages Chrome CDP (Chrome DevTools Protocol) connections for browser MCP tools. Currently, the CDP port is auto-computed as `19222 + (hash(container_name) % 100)`, giving each container a deterministic but inflexible port assignment.

This auto-computation works for the happy path but fails when:
- Port conflicts with existing services
- User wants to connect to an already-running Chrome on a known port
- User needs predictable ports for scripting or remote debugging

The existing codebase already has a pattern for flag-based port control (see `--port` in `od_start()` around line 273) and environment variable precedence (see `PORT_BIND`). The implementation follows established patterns.

## Goals / Non-Goals

**Goals:**
- Allow users to specify a Chrome CDP port via `--cdp-port <port>` flag
- Allow users to specify via `CHROME_CDP_PORT` env var (for persistence in `~/.ai-sandbox/env`)
- Maintain clear precedence: flag > env var > auto-computed hash
- Validate port range (1–65535) and report errors clearly
- Preserve existing reuse-if-alive behavior (probe before launching)
- Document the new option in `--help-env`

**Non-Goals:**
- Changing the auto-computation algorithm
- Adding port validation for the host side (Docker Desktop handles this)
- Supporting remote Chrome connections (different host) — that's a separate feature
- Changing MCP config file format or key naming scheme

## Decisions

### 1. Flag name: `--cdp-port`

**Alternative considered:** `--chrome-port`, `--debugging-port`, `--browser-port`

**Decision:** `--cdp-port` — matches the protocol name (Chrome DevTools Protocol), concise, and unambiguous. The `--port` flag name is already used for `open-design` subcommand and could confuse users.

### 2. Precedence: flag > env var > auto-computed

**Alternative considered:** env var > flag (unusual), env var only (no flag)

**Decision:** Flag overrides env var, which overrides default. This follows CLI conventions (e.g., `PORT` env var vs `--port` flag in many tools). The env var provides persistence; the flag provides one-off override.

### 3. Port validation: reject at parse time

**Alternative considered:** validate later in the flow, allow Docker to handle it

**Decision:** Validate immediately in flag parsing (range 1–65535). Fail fast with clear error message. Follows existing pattern from `od_start()` line 276.

### 4. No changes to `lib/playwright-mcp-config.sh`

The existing `pmcp::register_host_chrome()` function already accepts port as a parameter. The implementation only needs to set `HOST_CHROME_CDP_PORT` correctly before that function is called. No config layer changes needed.

### 5. Profile directory uses manual port

When `--cdp-port 9222` is used, the Chrome profile directory becomes `$SANDBOX_DIR/chrome-profile-9222` (not the hash-based name). This is intentional — it lets users find their profile by the port they chose.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| User picks a port in use by another service | Error message includes the port; probe will fail and fallback activates |
| User picks a port below 19222 (outside typical range) | Allowed — no minimum enforced beyond 1. Chrome accepts any valid port |
| Multiple containers manually set same port | They share Chrome (reuse-if-alive), same as hash collision — by design |
| Env var `CHROME_CDP_PORT` set but MCP tools not installed | Handled by existing check at line 1262 — skips if no MCP installed |
