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

# Probe and remove .mcp.<prefix>* entries whose CDP port is no longer alive.
# Used to garbage-collect stale per-container Chrome MCP entries.
# Args: $1 = config file path, $2 = key prefix (e.g. "playwright_", "chrome-devtools_")
pmcp::sweep_dead() {
  local cfg="$1" prefix="$2"
  [[ -f "$cfg" ]] || return 0

  local keys dead_keys=()
  keys=$(jq -r --arg p "$prefix" '(.mcp // {}) | keys[] | select(startswith($p))' "$cfg" 2>/dev/null || true)
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    # Find an http:// or ws:// URL in the command — any flag name works.
    local cmd_url
    cmd_url=$(jq -r --arg k "$key" \
      '.mcp[$k].command[]? | select(startswith("http://") or startswith("ws://"))' \
      "$cfg" 2>/dev/null | head -1)
    [[ -z "$cmd_url" ]] && continue
    # Extract port from http://host:port[/path] or ws://host:port[/path]
    local hostport="${cmd_url#*://}"   # host:port[/path]
    hostport="${hostport%%/*}"          # host:port
    local entry_port="${hostport##*:}" # port
    if ! pmcp::probe_chrome "$entry_port"; then
      dead_keys+=("$key")
    fi
  done <<< "$keys"

  (( ${#dead_keys[@]} == 0 )) && return 0

  local tmp="$cfg.tmp.$$"
  local args=()
  local i=0
  for k in "${dead_keys[@]+"${dead_keys[@]}"}"; do
    args+=(--arg "k$i" "$k")
    i=$((i + 1))
  done
  jq "${args[@]+"${args[@]}"}" \
    'reduce ([$ARGS.named | to_entries[] | select(.key|startswith("k")) | .value][]) as $k (.; del(.mcp[$k]))' \
    "$cfg" > "$tmp"
  mv "$tmp" "$cfg"
  chmod 600 "$cfg"

  echo "  🧹 pmcp: removed ${#dead_keys[@]} stale ${prefix}* entr$([ ${#dead_keys[@]} -eq 1 ] && echo y || echo ies): ${dead_keys[*]}"
}

# Register (or overwrite) an MCP entry.
# Args: $1 = config file path, $2 = key, $3 = command as JSON array string
#   e.g. pmcp::register cfg playwright_port_19222 '["playwright-mcp","--cdp-endpoint","http://192.168.65.254:19222"]'
pmcp::register() {
  local cfg="$1" key="$2" cmd_json="$3"
  [[ -f "$cfg" ]] || echo '{}' > "$cfg"
  local tmp="$cfg.tmp.$$"
  jq --arg key "$key" --argjson cmd "$cmd_json" \
    '.mcp = (.mcp // {}) | .mcp[$key] = {"type":"local","command":$cmd}' \
    "$cfg" > "$tmp"
  mv "$tmp" "$cfg"
  chmod 600 "$cfg"
  echo "  ➕ pmcp: registered $key"
}

# Register both playwright-mcp and chrome-devtools-mcp for a host Chrome on
# a given CDP port. Sweeps dead entries of both prefixes first, then writes
# the new entries. MUST be called inside a flock.
# Args: $1 = cfg, $2 = port, $3 = playwright key, $4 = chrome-devtools key
pmcp::register_host_chrome() {
  local cfg="$1" port="$2" pw_key="$3" cd_key="$4"
  local url="http://$PMCP_DOCKER_HOST_IP:$port"

  pmcp::sweep_dead "$cfg" "playwright_"
  pmcp::sweep_dead "$cfg" "chrome-devtools_"
  pmcp::register "$cfg" "$pw_key" \
    "[\"playwright-mcp\",\"--cdp-endpoint\",\"$url\"]"
  pmcp::register "$cfg" "$cd_key" \
    "[\"chrome-devtools-mcp\",\"--browserUrl\",\"$url\"]"
}

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
  for k in "${dead_keys[@]+"${dead_keys[@]}"}"; do
    args+=(--arg "k$i" "$k")
    i=$((i + 1))
  done
  jq "${args[@]+"${args[@]}"}" --arg name "$name" --arg host "$PMCP_DOCKER_HOST_IP" --arg port "$port" \
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

# Run a command while holding an exclusive lock on $1. Uses flock(1) if available,
# else falls back to a mkdir-based mutex (portable across macOS where flock is
# not built-in). Times out after 5 seconds; on timeout, returns 99 without
# running the command. Returns the command's exit status otherwise.
# Args: $1 = lockfile path, $2... = command + args
pmcp::with_lock() {
  local lockfile="$1"; shift
  local timeout=5

  if command -v flock >/dev/null 2>&1; then
    (
      flock -w "$timeout" 9 || exit 99
      "$@"
    ) 9>"$lockfile"
    return $?
  fi

  # mkdir-based fallback. mkdir is atomic on POSIX filesystems.
  local mutex="${lockfile}.d"
  local waited=0
  while ! mkdir "$mutex" 2>/dev/null; do
    if (( waited >= timeout * 10 )); then
      return 99
    fi
    sleep 0.1
    waited=$((waited + 1))
  done
  trap "rmdir '$mutex' 2>/dev/null || true" EXIT
  "$@"
  local rc=$?
  rmdir "$mutex" 2>/dev/null || true
  trap - EXIT
  return $rc
}
