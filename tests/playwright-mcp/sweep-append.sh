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
