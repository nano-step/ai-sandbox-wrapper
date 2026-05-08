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

# Host address from container (Docker Desktop on Mac).
PMCP_DOCKER_HOST_IP="${PMCP_DOCKER_HOST_IP:-192.168.65.254}"

# Sweep dead playwright_* entries and append a new one. MUST be called inside
# a flock by the caller. Does not acquire the lock itself, by design — locking
# happens around a larger critical section in the caller.
# Args: $1 = config file path, $2 = full MCP key (e.g. playwright_foo_19223), $3 = port
pmcp::sweep_and_append() {
  local cfg="$1" name="$2" port="$3"

  if [[ ! -f "$cfg" ]]; then
    echo "  ⚠️  pmcp: config file not found: $cfg" >&2
    return 1
  fi

  # Collect dead keys
  local keys dead_keys=()
  keys=$(jq -r '(.mcp // {}) | keys[] | select(startswith("playwright_"))' "$cfg" 2>/dev/null || true)
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    local cmd_url
    cmd_url=$(jq -r --arg k "$key" '.mcp[$k].command[]? | select(startswith("http://"))' "$cfg" 2>/dev/null | head -1)
    [[ -z "$cmd_url" ]] && continue
    local entry_port="${cmd_url##*:}"
    if ! pmcp::probe_chrome "$entry_port"; then
      dead_keys+=("$key")
    fi
  done <<< "$keys"

  # Build --arg flags for each dead key, then run a single jq invocation
  # that deletes them all and appends the new entry.
  local tmp="$cfg.tmp.$$"
  local args=()
  local i=0
  for k in "${dead_keys[@]}"; do
    args+=(--arg "k$i" "$k")
    i=$((i + 1))
  done
  jq "${args[@]}" --arg name "$name" --arg host "$PMCP_DOCKER_HOST_IP" --arg port "$port" \
    '
      def setup($args; $name; $host; $port):
        .mcp = (.mcp // {})
        | reduce ($args[]) as $k (.; del(.mcp[$k]))
        | .mcp[$name] = {"type":"local","command":["playwright-mcp","--cdp-endpoint","http://" + $host + ":" + $port]};
      setup([$ARGS.named | to_entries[] | select(.key|startswith("k")) | .value]; $name; $host; $port)
    ' "$cfg" > "$tmp"

  mv "$tmp" "$cfg"
  chmod 600 "$cfg"

  if (( ${#dead_keys[@]} > 0 )); then
    echo "  🧹 pmcp: removed ${#dead_keys[@]} stale entr$([ ${#dead_keys[@]} -eq 1 ] && echo y || echo ies): ${dead_keys[*]}"
  fi
  echo "  ➕ pmcp: registered $name → http://$PMCP_DOCKER_HOST_IP:$port"
}
