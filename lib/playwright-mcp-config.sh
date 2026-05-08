#!/usr/bin/env bash
# Helpers for managing per-container Playwright MCP entries in the shared
# OpenCode config (~/.config/opencode/opencode.json). All functions are pure
# except where noted. Callers are responsible for holding the flock around
# pmcp::sweep_and_append.

# Replace any character outside [A-Za-z0-9_-] with underscore. Empty input
# becomes "unnamed". Used to keep MCP keys jq-safe.
pmcp::sanitize_name() {
  local input="${1:-}"
  if [[ -z "$input" ]]; then
    echo "unnamed"
    return
  fi
  printf '%s' "$input" | tr -c 'A-Za-z0-9_-' '_'
}

# Probe a port for a valid Chrome CDP endpoint. Returns 0 if /json/version
# responds with JSON containing a "Browser" field within the timeout.
# Args: $1 = port
pmcp::probe_chrome() {
  local port="$1"
  local body
  body=$(curl -fsS --max-time 0.5 "http://localhost:$port/json/version" 2>/dev/null) || return 1
  [[ "$body" == *'"Browser"'* ]] || return 1
  return 0
}
