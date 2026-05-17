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
class ThreadedHTTPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    daemon_threads = True
    allow_reuse_address = True
srv = ThreadedHTTPServer(('127.0.0.1', $PROBE_PORT), H)
threading.Thread(target=srv.serve_forever, daemon=True).start()
import time; time.sleep(300)
" &
STUB_PID=$!
trap "kill $STUB_PID 2>/dev/null || true" EXIT
# Wait for the python stub to start listening (up to 5s).
for _ in $(seq 1 50); do
  curl -fsS --max-time 0.2 "http://localhost:$PROBE_PORT/json/version" >/dev/null 2>&1 && break
  sleep 0.1
done

pmcp::probe_chrome "$PROBE_PORT" || { echo "FAIL probe alive"; exit 1; }
! pmcp::probe_chrome 39872 || { echo "FAIL probe dead"; exit 1; }

echo "PASS: probe_chrome"

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

# --- Test: concurrent appenders preserve all writes ---
CFG2="$TMPDIR/opencode2.json"
LOCK2="$TMPDIR/.lock2"
echo '{"mcp":{}}' > "$CFG2"

# Launch 5 background appenders, each adding a unique key (using PROBE_PORT for liveness)
concurrent_pids=()
for i in 1 2 3 4 5; do
  (
    flock 9
    pmcp::sweep_and_append "$CFG2" "playwright_concurrent_$i" "$PROBE_PORT"
  ) 9>"$LOCK2" &
  concurrent_pids+=($!)
done
# Wait only for these specific PIDs — bare `wait` would also wait on the
# stub HTTP server (sleeping 300s) and hang the test.
wait "${concurrent_pids[@]}"

count=$(jq '[.mcp | keys[] | select(startswith("playwright_concurrent_"))] | length' "$CFG2")
[[ "$count" == "5" ]] || { echo "FAIL concurrent: got $count entries, expected 5"; jq . "$CFG2"; exit 1; }

echo "PASS: concurrent"

# --- Test: with_lock works (flock or mkdir fallback) ---
LOCK3="$TMPDIR/.lock3"
GUARDED_FILE="$TMPDIR/guarded.txt"
echo 0 > "$GUARDED_FILE"

# Increment guarded file from 5 concurrent processes
increment() {
  local current next
  current=$(cat "$GUARDED_FILE")
  sleep 0.05
  next=$((current + 1))
  echo "$next" > "$GUARDED_FILE"
}

withlock_pids=()
for i in 1 2 3 4 5; do
  pmcp::with_lock "$LOCK3" increment &
  withlock_pids+=($!)
done
wait "${withlock_pids[@]}"

final=$(cat "$GUARDED_FILE")
[[ "$final" == "5" ]] || { echo "FAIL with_lock: got $final, expected 5"; exit 1; }
echo "PASS: with_lock"

# --- Test: register_host_chrome writes both playwright + chrome-devtools entries ---
CFG3="$TMPDIR/opencode3.json"
LOCK3B="$TMPDIR/.lock3b"
echo '{"mcp":{}}' > "$CFG3"

pmcp::with_lock "$LOCK3B" pmcp::register_host_chrome \
  "$CFG3" "$PROBE_PORT" "playwright_port_$PROBE_PORT" "chrome-devtools_port_$PROBE_PORT"

jq -e ".mcp.playwright_port_$PROBE_PORT" "$CFG3" >/dev/null \
  || { echo "FAIL register_host_chrome: missing playwright entry"; exit 1; }
jq -e '.mcp."chrome-devtools_port_'"$PROBE_PORT"'"' "$CFG3" >/dev/null \
  || { echo "FAIL register_host_chrome: missing chrome-devtools entry"; exit 1; }

pw_flag=$(jq -r ".mcp.playwright_port_$PROBE_PORT.command[1]" "$CFG3")
[[ "$pw_flag" == "--cdp-endpoint" ]] \
  || { echo "FAIL register_host_chrome: playwright flag was '$pw_flag'"; exit 1; }

cd_flag=$(jq -r '.mcp."chrome-devtools_port_'"$PROBE_PORT"'".command[1]' "$CFG3")
[[ "$cd_flag" == "--browserUrl" ]] \
  || { echo "FAIL register_host_chrome: chrome-devtools flag was '$cd_flag'"; exit 1; }

pw_url=$(jq -r ".mcp.playwright_port_$PROBE_PORT.command[2]" "$CFG3")
cd_url=$(jq -r '.mcp."chrome-devtools_port_'"$PROBE_PORT"'".command[2]' "$CFG3")
[[ "$pw_url" == "$cd_url" ]] \
  || { echo "FAIL register_host_chrome: URL mismatch '$pw_url' vs '$cd_url'"; exit 1; }
[[ "$pw_url" == *":$PROBE_PORT" ]] \
  || { echo "FAIL register_host_chrome: bad url '$pw_url'"; exit 1; }

echo "PASS: register_host_chrome"

# --- Test: sweep_dead handles chrome-devtools prefix and ws:// URLs ---
pmcp::probe_chrome "$PROBE_PORT" || { echo "FAIL precheck: stub died before sweep_dead test"; exit 1; }
CFG4="$TMPDIR/opencode4.json"
cat > "$CFG4" <<JSON
{
  "mcp": {
    "chrome-devtools_port_$PROBE_PORT": {"type":"local","command":["chrome-devtools-mcp","--browserUrl","http://192.168.65.254:$PROBE_PORT"]},
    "chrome-devtools_port_39998":      {"type":"local","command":["chrome-devtools-mcp","--browserUrl","http://192.168.65.254:39998"]},
    "chrome-devtools_ws_dead":         {"type":"local","command":["chrome-devtools-mcp","--wsEndpoint","ws://192.168.65.254:39997/devtools/browser/abc"]},
    "playwright_port_$PROBE_PORT":     {"type":"local","command":["playwright-mcp","--cdp-endpoint","http://192.168.65.254:$PROBE_PORT"]}
  }
}
JSON
pmcp::sweep_dead "$CFG4" "chrome-devtools_"

jq -e ".mcp.\"chrome-devtools_port_$PROBE_PORT\"" "$CFG4" >/dev/null \
  || { echo "FAIL sweep_dead chrome-devtools: alive removed"; exit 1; }
jq -e '.mcp."chrome-devtools_port_39998"' "$CFG4" >/dev/null \
  && { echo "FAIL sweep_dead chrome-devtools: dead http entry survived"; exit 1; }
jq -e '.mcp."chrome-devtools_ws_dead"' "$CFG4" >/dev/null \
  && { echo "FAIL sweep_dead chrome-devtools: dead ws entry survived"; exit 1; }
jq -e ".mcp.playwright_port_$PROBE_PORT" "$CFG4" >/dev/null \
  || { echo "FAIL sweep_dead chrome-devtools: cross-prefix damage"; exit 1; }

echo "PASS: sweep_dead chrome-devtools"

echo "All tests passed."
