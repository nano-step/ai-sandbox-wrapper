# Proposal: Add Manual CDP Port Selection

## Why

When running `ai-run opencode`, the Chrome CDP port is auto-computed as `19222 + (hash(container_name) % 100)`. This causes problems when:

- The auto-assigned port conflicts with another service already using that port
- The user already has Chrome running with `--remote-debugging-port` on a known port and wants to reuse it instead of launching a new instance
- The user wants to connect to a Chrome instance on a remote machine or in a different Docker network
- The user wants deterministic, predictable port numbers for scripting or debugging workflows

Currently there is no way to override this. Adding a `--cdp-port` flag (and `CHROME_CDP_PORT` env var) lets users control which port Chrome's CDP endpoint binds to.

## What Changes

- Add `--cdp-port <port>` flag to `ai-run`'s flag parser (alongside existing `--expose`, `--shell`, etc.)
- Add `CHROME_CDP_PORT` env var support (read from `~/.ai-sandbox/env` or shell environment)
- Precedence: `--cdp-port` flag > `CHROME_CDP_PORT` env var > auto-computed hash
- When a manual port is provided, skip the hash-based port computation but still perform the reuse-if-alive probe
- Validate port range (1–65535) and report errors clearly
- Add help text for the new flag in `--help-env`

## Capabilities

### Modified Capabilities

- `browser-mcp-tools`: Add requirement for manual CDP port configuration via `--cdp-port` flag and `CHROME_CDP_PORT` env var, including precedence rules, validation, and reuse-if-alive behavior.

### New Capabilities

(None — this extends existing browser-mcp-tools behavior, no new spec needed.)

## Impact

| Area | Impact |
|------|--------|
| `bin/ai-run` | Flag parsing (line 464–517), port assignment logic (line 1288–1293), help text |
| `lib/playwright-mcp-config.sh` | No changes needed — `pmcp::register_host_chrome` already accepts port as a parameter |
| `~/.ai-sandbox/env` | New optional `CHROME_CDP_PORT` variable |
| Backward compatibility | Fully backward compatible — auto-computed port remains the default when neither flag nor env var is set |
| Security | No new attack surface — port validation is range-checked (1–65535), same as existing `--port` flag |
