# Multi-container Playwright MCP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `bin/ai-run` register a unique, named MCP entry per container in the shared OpenCode config without races, sweep dead entries on each start, and tell the in-container agent which entry is its own via env var.

**Architecture:** Each container picks a deterministic CDP port from its name. A new shell helper library (`lib/playwright-mcp-config.sh`) owns all config-file mutation: it acquires `flock`, sweeps entries whose port no longer responds with valid CDP JSON, then appends `playwright_<container>_<port>`. `bin/ai-run` calls this helper, passes `PLAYWRIGHT_MCP_NAME` and `PLAYWRIGHT_PORT` into the container as env vars, and the repo's `AGENTS.md` is updated with one line that tells the agent to consult those env vars.

**Tech Stack:** Bash, `jq`, `flock`, `curl`. macOS Docker Desktop. OpenCode config at `~/.config/opencode/opencode.json`.

**Spec:** [`docs/superpowers/specs/2026-05-08-multi-container-playwright-mcp-design.md`](../specs/2026-05-08-multi-container-playwright-mcp-design.md)

---

## File structure

- **Create** `lib/playwright-mcp-config.sh` — pure functions for config mutation, port probing, and name sanitization. Sourced by `bin/ai-run`.
- **Create** `tests/playwright-mcp/sweep-append.sh` — shell test exercising the helper end-to-end.
- **Modify** `bin/ai-run` — replace racy block with helper calls; pass env vars to container.
- **Modify** `bin/ai-run` `configure_opencode_mcp` function (~line 2080) — skip writing static `playwright` entry when host Chrome mode is active.
- **Modify** `AGENTS.md` (repo root) — add one line about `PLAYWRIGHT_MCP_NAME`.

---

## Task 1: Create the helper library skeleton with name sanitization

**Files:**
- Create: `lib/playwright-mcp-config.sh`
- Test: `tests/playwright-mcp/sweep-append.sh`

- [ ] **Step 1: Write the failing test for name sanitization**

Create `tests/playwright-mcp/sweep-append.sh` with this initial content:

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
source "$ROOT/lib/playwright-mcp-config.sh"

# --- Test: sanitize_name ---
result=$(pmcp::sanitize_name "my-project_v2")
[[ "$result" == "my-project_v2" ]] || { echo "FAIL sanitize identity: got '$result'"; exit 1; }

result=$(pmcp::sanitize_name "weird name!@#")
[[ "$result" == "weird_name___" ]] || { echo "FAIL sanitize special: got '$result'"; exit 1; }

result=$(pmcp::sanitize_name "")
[[ "$result" == "unnamed" ]] || { echo "FAIL sanitize empty: got '$result'"; exit 1; }

echo "PASS: sanitize_name"
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `bash tests/playwright-mcp/sweep-append.sh`
Expected: FAIL with "No such file or directory" for `lib/playwright-mcp-config.sh`.

- [ ] **Step 3: Create the helper with the sanitize function**

Create `lib/playwright-mcp-config.sh`:

```bash
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
  echo "$input" | tr -c 'A-Za-z0-9_-' '_' | tr -d '\n'
}
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `bash tests/playwright-mcp/sweep-append.sh`
Expected: `PASS: sanitize_name`

- [ ] **Step 5: Commit**

```bash
git add lib/playwright-mcp-config.sh tests/playwright-mcp/sweep-append.sh
git commit -m "feat(playwright-mcp): add helper library with name sanitization"
```

---

## Task 2: Add the CDP probe function

**Files:**
- Modify: `lib/playwright-mcp-config.sh`
- Modify: `tests/playwright-mcp/sweep-append.sh`

- [ ] **Step 1: Append failing tests for `pmcp::probe_chrome`**

Append to `tests/playwright-mcp/sweep-append.sh` (before the final `echo "PASS"`):

```bash
# --- Test: probe_chrome ---
# Start a stub HTTP server that returns valid Chrome CDP JSON
PROBE_PORT=39871
python3 -c "
import http.server, socketserver, json, threading
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/json/version':
            body = json.dumps({'Browser':'Chrome/120','webSocketDebuggerUrl':'ws://x'}).encode()
            self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404); self.end_headers()
    def log_message(self, *a): pass
srv = socketserver.TCPServer(('127.0.0.1', $PROBE_PORT), H)
threading.Thread(target=srv.serve_forever, daemon=True).start()
import time; time.sleep(60)
" &
STUB_PID=$!
trap "kill $STUB_PID 2>/dev/null || true" EXIT
sleep 0.3

pmcp::probe_chrome "$PROBE_PORT" || { echo "FAIL probe alive"; exit 1; }
! pmcp::probe_chrome 39872 || { echo "FAIL probe dead"; exit 1; }

echo "PASS: probe_chrome"
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `bash tests/playwright-mcp/sweep-append.sh`
Expected: FAIL — `pmcp::probe_chrome: command not found`.

- [ ] **Step 3: Add the probe function**

Append to `lib/playwright-mcp-config.sh`:

```bash
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
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `bash tests/playwright-mcp/sweep-append.sh`
Expected: `PASS: sanitize_name` and `PASS: probe_chrome`.

- [ ] **Step 5: Commit**

```bash
git add lib/playwright-mcp-config.sh tests/playwright-mcp/sweep-append.sh
git commit -m "feat(playwright-mcp): add CDP probe function"
```

---

## Task 3: Implement sweep + append under flock

**Files:**
- Modify: `lib/playwright-mcp-config.sh`
- Modify: `tests/playwright-mcp/sweep-append.sh`

- [ ] **Step 1: Append failing test for sweep_and_append**

Append to `tests/playwright-mcp/sweep-append.sh`:

```bash
# --- Test: sweep_and_append ---
TMPDIR=$(mktemp -d)
trap "kill $STUB_PID 2>/dev/null || true; rm -rf '$TMPDIR'" EXIT
CFG="$TMPDIR/opencode.json"
LOCK="$TMPDIR/.lock"

# Pre-populate config with one live (PROBE_PORT) and one dead (39999) entry
cat > "$CFG" <<JSON
{
  "mcp": {
    "playwright_alive_${PROBE_PORT}": {"type":"local","command":["playwright-mcp","--cdp-endpoint","http://192.168.65.254:${PROBE_PORT}"]},
    "playwright_dead_39999":         {"type":"local","command":["playwright-mcp","--cdp-endpoint","http://192.168.65.254:39999"]},
    "other_server":                  {"type":"local","command":["something-else"]}
  }
}
JSON

(
  flock 9
  pmcp::sweep_and_append "$CFG" "playwright_test_$PROBE_PORT" "$PROBE_PORT"
) 9>"$LOCK"

# After sweep+append: alive preserved, dead removed, new added, other_server untouched
jq -e ".mcp.playwright_alive_${PROBE_PORT}" "$CFG" >/dev/null || { echo "FAIL alive removed"; exit 1; }
jq -e ".mcp.playwright_dead_39999" "$CFG" >/dev/null && { echo "FAIL dead survived"; exit 1; }
jq -e ".mcp.playwright_test_$PROBE_PORT" "$CFG" >/dev/null || { echo "FAIL new not added"; exit 1; }
jq -e ".mcp.other_server" "$CFG" >/dev/null || { echo "FAIL other_server clobbered"; exit 1; }

# Verify endpoint URL embedded correctly
url=$(jq -r ".mcp.playwright_test_$PROBE_PORT.command[2]" "$CFG")
[[ "$url" == "http://192.168.65.254:$PROBE_PORT" ]] || { echo "FAIL bad url: $url"; exit 1; }

echo "PASS: sweep_and_append"
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `bash tests/playwright-mcp/sweep-append.sh`
Expected: FAIL — `pmcp::sweep_and_append: command not found`.

- [ ] **Step 3: Implement sweep_and_append**

Append to `lib/playwright-mcp-config.sh`:

```bash
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
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `bash tests/playwright-mcp/sweep-append.sh`
Expected: `PASS: sweep_and_append` after the prior PASS lines.

- [ ] **Step 5: Commit**

```bash
git add lib/playwright-mcp-config.sh tests/playwright-mcp/sweep-append.sh
git commit -m "feat(playwright-mcp): sweep dead entries and append new under flock"
```

---

## Task 4: Add lock-contention test

**Files:**
- Modify: `tests/playwright-mcp/sweep-append.sh`

- [ ] **Step 1: Append concurrency test**

Append to `tests/playwright-mcp/sweep-append.sh`:

```bash
# --- Test: concurrent appenders preserve all writes ---
CFG2="$TMPDIR/opencode2.json"
LOCK2="$TMPDIR/.lock2"
echo '{"mcp":{}}' > "$CFG2"

# Launch 5 background appenders, each adding a unique key (using PROBE_PORT for liveness)
for i in 1 2 3 4 5; do
  (
    flock 9
    pmcp::sweep_and_append "$CFG2" "playwright_concurrent_$i" "$PROBE_PORT"
  ) 9>"$LOCK2" &
done
wait

count=$(jq '[.mcp | keys[] | select(startswith("playwright_concurrent_"))] | length' "$CFG2")
[[ "$count" == "5" ]] || { echo "FAIL concurrent: got $count entries, expected 5"; jq . "$CFG2"; exit 1; }

echo "PASS: concurrent"
echo "All tests passed."
```

- [ ] **Step 2: Run the full test file**

Run: `bash tests/playwright-mcp/sweep-append.sh`
Expected: `PASS: concurrent` and `All tests passed.`

- [ ] **Step 3: Commit**

```bash
git add tests/playwright-mcp/sweep-append.sh
git commit -m "test(playwright-mcp): verify flock prevents lost writes under concurrency"
```

---

## Task 5: Wire helper into `bin/ai-run` (replace racy block)

**Files:**
- Modify: `bin/ai-run` (lines ~786–847, the host Chrome CDP block)

- [ ] **Step 1: Source the helper near the top of the host-chrome block**

In `bin/ai-run`, find the line:

```bash
# Host Chrome for Playwright MCP (via CDP - Chrome DevTools Protocol)
```

Replace the entire block from that comment through the closing `fi` at the end of the host-Chrome section (around line 847) with this updated version. Read the file first to confirm exact line numbers; the marker is the comment above and the second `fi` after `OPENCODE_CONFIG_FILE`.

```bash
# Host Chrome for Playwright MCP (via CDP - Chrome DevTools Protocol)
# NOTE: macOS Chrome binary (Mach-O) cannot run inside a Linux container.
# Instead, we launch Chrome on the host with --remote-debugging-port and
# connect from the container via CDP. Each container gets its own port +
# its own MCP entry; entries are sweep-cleaned on every start.
HOST_CHROME_CDP=false
HOST_CHROME_CDP_PORT=19222
PLAYWRIGHT_MCP_NAME=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/playwright-mcp-config.sh
[[ -f "$SCRIPT_DIR/lib/playwright-mcp-config.sh" ]] && source "$SCRIPT_DIR/lib/playwright-mcp-config.sh"

if [[ "$TOOL" == "opencode" ]] && command -v jq &>/dev/null && [[ -f "$AI_SANDBOX_CONFIG" ]] && declare -f pmcp::sanitize_name >/dev/null; then
  PLAYWRIGHT_HOST_CHROME=$(jq -r '.mcp.chromePath // empty' "$AI_SANDBOX_CONFIG" 2>/dev/null)
  if [[ -n "$PLAYWRIGHT_HOST_CHROME" ]] && [[ -f "$PLAYWRIGHT_HOST_CHROME" ]]; then
    HOST_CHROME_CDP=true
    echo "🌐 Host Chrome CDP mode: $PLAYWRIGHT_HOST_CHROME"

    # CONTAINER_NAME has the form "--name foo" or is empty. Extract the value.
    CONTAINER_NAME_VALUE="${CONTAINER_NAME#--name }"
    [[ "$CONTAINER_NAME_VALUE" == "$CONTAINER_NAME" ]] && CONTAINER_NAME_VALUE="anon-$$"
    SAFE_NAME=$(pmcp::sanitize_name "$CONTAINER_NAME_VALUE")

    # Deterministic port per container name
    CONTAINER_HASH=$(echo "$CONTAINER_NAME_VALUE" | md5sum | cut -c1-4)
    HOST_CHROME_CDP_PORT=$((19222 + 0x$CONTAINER_HASH % 100))
    PLAYWRIGHT_MCP_NAME="playwright_${SAFE_NAME}_${HOST_CHROME_CDP_PORT}"

    # Reuse-if-alive: probe before launching
    if pmcp::probe_chrome "$HOST_CHROME_CDP_PORT"; then
      echo "  ✅ Chrome already running on port $HOST_CHROME_CDP_PORT (reusing)"
    else
      echo "  🚀 Launching Chrome with remote debugging on port $HOST_CHROME_CDP_PORT..."
      mkdir -p "$SANDBOX_DIR/chrome-profile-$HOST_CHROME_CDP_PORT"
      "$PLAYWRIGHT_HOST_CHROME" \
        --remote-debugging-port="$HOST_CHROME_CDP_PORT" \
        --user-data-dir="$SANDBOX_DIR/chrome-profile-$HOST_CHROME_CDP_PORT" \
        --no-first-run \
        --no-default-browser-check \
        &>/dev/null &
      CHROME_PID=$!
      for i in {1..20}; do
        if pmcp::probe_chrome "$HOST_CHROME_CDP_PORT"; then
          echo "  ✅ Chrome ready (PID: $CHROME_PID, port: $HOST_CHROME_CDP_PORT)"
          echo "  👀 You can watch the browser window to see what the AI is doing"
          break
        fi
        sleep 0.25
      done
      if ! pmcp::probe_chrome "$HOST_CHROME_CDP_PORT"; then
        echo "  ⚠️  Chrome failed to start. Falling back to container Chromium."
        HOST_CHROME_CDP=false
        kill "$CHROME_PID" 2>/dev/null || true
        PLAYWRIGHT_MCP_NAME=""
      fi
    fi

    # Locked sweep+append on the shared OpenCode config
    if [[ "$HOST_CHROME_CDP" == "true" ]]; then
      OPENCODE_CONFIG_FILE="$HOME/.config/opencode/opencode.json"
      LOCK_FILE="$HOME/.config/opencode/.playwright.lock"
      mkdir -p "$(dirname "$OPENCODE_CONFIG_FILE")"
      [[ -f "$OPENCODE_CONFIG_FILE" ]] || echo '{}' > "$OPENCODE_CONFIG_FILE"
      if (
        flock -w 5 9 || exit 99
        pmcp::sweep_and_append "$OPENCODE_CONFIG_FILE" "$PLAYWRIGHT_MCP_NAME" "$HOST_CHROME_CDP_PORT"
      ) 9>"$LOCK_FILE"; then
        :
      else
        rc=$?
        if [[ "$rc" == "99" ]]; then
          echo "  ⚠️  Could not acquire MCP config lock within 5s; skipping registration."
          PLAYWRIGHT_MCP_NAME=""
        else
          echo "  ⚠️  MCP config update failed (rc=$rc); skipping registration."
          PLAYWRIGHT_MCP_NAME=""
        fi
      fi
    fi
  fi
fi
```

- [ ] **Step 2: Run shellcheck on the modified file**

Run: `shellcheck -x bin/ai-run | head -40`
Expected: No new errors introduced by the changes (warnings unrelated to this block can be ignored).

- [ ] **Step 3: Smoke test the script doesn't crash**

Run: `bash -n bin/ai-run`
Expected: No syntax errors.

- [ ] **Step 4: Commit**

```bash
git add bin/ai-run
git commit -m "fix(ai-run): use locked sweep+append for per-container playwright MCP"
```

---

## Task 6: Pass MCP env vars into the container

**Files:**
- Modify: `bin/ai-run` (the `DOCKER_ARGS+=(...)` block, ~line 2680)

- [ ] **Step 1: Locate the DOCKER_ARGS block**

Run: `grep -n 'DOCKER_ARGS+=(-e' bin/ai-run`
Expected: Several lines near the bottom showing existing `-e` env injections (e.g. `TERM`, `COLORTERM`).

- [ ] **Step 2: Add the playwright env vars**

Find the line:

```bash
DOCKER_ARGS+=(-e COLORTERM="$COLORTERM")
```

Insert immediately after it:

```bash
if [[ -n "${PLAYWRIGHT_MCP_NAME:-}" ]]; then
  DOCKER_ARGS+=(-e "PLAYWRIGHT_MCP_NAME=$PLAYWRIGHT_MCP_NAME")
  DOCKER_ARGS+=(-e "PLAYWRIGHT_PORT=$HOST_CHROME_CDP_PORT")
fi
```

- [ ] **Step 3: Verify with `bash -n`**

Run: `bash -n bin/ai-run`
Expected: No syntax errors.

- [ ] **Step 4: Commit**

```bash
git add bin/ai-run
git commit -m "feat(ai-run): pass PLAYWRIGHT_MCP_NAME and PLAYWRIGHT_PORT into container"
```

---

## Task 7: Skip static `playwright` MCP entry in `configure_opencode_mcp` when host Chrome mode is on

**Files:**
- Modify: `bin/ai-run` `configure_opencode_mcp` function (around lines 2080–2150)

- [ ] **Step 1: Locate the static playwright entry writes**

Run: `grep -n 'add_mcp_config "playwright"' bin/ai-run`
Expected: Multiple lines, two for host-Chrome variants and two for container-Chromium variants.

- [ ] **Step 2: Replace the host-Chrome variants with a no-op**

For each of the two occurrences that look like:

```bash
if add_mcp_config "playwright" "[\"playwright-mcp\", \"--cdp-endpoint\", \"http://192.168.65.254:9222\"]"; then
  echo "  ✓ Configured Playwright MCP (host Chrome via CDP)"
  configured_any=true
fi
```

and:

```bash
if add_mcp_config "playwright" "[\"playwright-mcp\", \"--cdp-endpoint\", \"http://host.docker.internal:9222\"]"; then
  echo "    ✓ Configured (host Chrome via CDP)"
  configured_any=true
fi
```

Replace each with:

```bash
echo "  ℹ️  Playwright MCP entry will be registered per-container at runtime (host Chrome mode)."
configured_any=true
```

(Adjust indentation to match the surrounding block — 2 spaces for the first occurrence, 4 spaces for the second.)

- [ ] **Step 3: Verify the container-Chromium fallback paths are unchanged**

Run: `grep -n 'add_mcp_config "playwright"' bin/ai-run`
Expected: Only the `--headless --browser chromium` invocations remain — host-Chrome ones are gone.

- [ ] **Step 4: Verify with `bash -n`**

Run: `bash -n bin/ai-run`
Expected: No syntax errors.

- [ ] **Step 5: Commit**

```bash
git add bin/ai-run
git commit -m "refactor(ai-run): skip static playwright MCP entry when host Chrome mode active"
```

---

## Task 8: Update `AGENTS.md` with env-var hint

**Files:**
- Modify: `AGENTS.md` (repo root)

- [ ] **Step 1: Read the current `AGENTS.md` to find a good insertion point**

Run: `grep -n -i 'mcp\|playwright\|tool' AGENTS.md | head -20`
Expected: Some context for where MCP/tool guidance lives. If none, insert at the top under any existing heading; otherwise create a new section.

- [ ] **Step 2: Append the playwright-MCP awareness section**

Add this section to `AGENTS.md` (at the bottom or near other tool guidance):

```markdown
## Playwright MCP server name

If the env var `PLAYWRIGHT_MCP_NAME` is set in your container shell, that is
the MCP server you should use for browser automation. Other servers in the
OpenCode config whose names start with `playwright_` belong to other
containers — do not use them. If `PLAYWRIGHT_MCP_NAME` is unset, fall back to
the server simply named `playwright` (in-container Chromium fallback).

To check at runtime: `echo "$PLAYWRIGHT_MCP_NAME"` in a shell.
```

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs(AGENTS): document PLAYWRIGHT_MCP_NAME env var for browser automation"
```

---

## Task 9: Manual integration test

**Files:** None — manual verification.

- [ ] **Step 1: Verify the chromePath is configured**

Run: `jq '.mcp.chromePath' ~/.ai-sandbox/config.json`
Expected: A path to a Chrome binary (e.g. `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`). If `null` or `empty`, set it via `bin/ai-run --config` or by editing the file directly before continuing.

- [ ] **Step 2: Launch first container and verify entry**

In terminal A: `bin/ai-run --tool opencode` (in any project dir).
Wait until container is up.

In terminal C (host): `jq '.mcp | with_entries(select(.key|startswith("playwright_")))' ~/.config/opencode/opencode.json`
Expected: One entry like `playwright_<container>_<port>`.

In terminal A inside container: `echo "$PLAYWRIGHT_MCP_NAME"`
Expected: Matches the entry key.

- [ ] **Step 3: Launch second container concurrently**

In terminal B (different project dir): `bin/ai-run --tool opencode`.

In terminal C: re-run the jq query.
Expected: Two distinct `playwright_*` entries with different ports.

- [ ] **Step 4: Verify Chrome reuse on restart**

Exit container A (Ctrl-D). Note its port. Re-launch in terminal A.
Expected: log line `Chrome already running on port X (reusing)`. Same MCP entry name.

- [ ] **Step 5: Verify dead-entry sweep**

Kill the second Chrome process on the host (find via `pgrep -f remote-debugging-port=PORT_B` and `kill`). Exit and re-launch container A.
In terminal C: re-run the jq query.
Expected: container B's entry is gone (swept); container A's entry remains.

- [ ] **Step 6: Document results**

If all five checks pass, mark this task complete. If any fail, file follow-ups before merging.

---

## Self-review notes

- Spec coverage: all five spec sections (port assignment, lifecycle, config mutation, container injection, removed code) map to Tasks 1–8. Failure-mode table in spec is exercised by Tasks 4 (lock contention), 5 (lock timeout), and 9 (sweep, reuse).
- Type/name consistency: function names `pmcp::sanitize_name`, `pmcp::probe_chrome`, `pmcp::sweep_and_append` used consistently across tasks. Env vars `PLAYWRIGHT_MCP_NAME`, `PLAYWRIGHT_PORT` used consistently.
- Open spec questions resolved: AGENTS.md mechanism = repo-root edit (Task 8); sanitization = `[A-Za-z0-9_-]` → underscore (Task 1). The optional `--prune-playwright` command is **not** included — Task 4's sweep-on-start is sufficient. Add later if usability requires.
