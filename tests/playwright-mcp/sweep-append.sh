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
