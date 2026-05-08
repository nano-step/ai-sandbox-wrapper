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
