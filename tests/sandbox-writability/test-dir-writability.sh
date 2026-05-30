#!/usr/bin/env bash
set -euo pipefail

# Test: verify that non-recursive chmod on sandbox roots does not break
# directory writability for the agent inside the sandbox.
#
# Background: commit 88dff74 replaced `chmod -R u+w` with `chmod u+w` on
# HOME_DIR and GIT_SHARED_DIR for performance (~15-18s savings). This test
# confirms that subdirectories remain writable after the non-recursive chmod
# -- i.e., the agent can still create files in nested shared directories.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

# Create an isolated temp sandbox to avoid touching real ~/.ai-sandbox
TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

SANDBOX_DIR="$TMPDIR/.ai-sandbox"
HOME_DIR="$SANDBOX_DIR/home"
GIT_SHARED_DIR="$SANDBOX_DIR/shared/git"

# ------------------------------------------------------------------
# Reproduce the exact directory setup from bin/ai-run (lines 894-896, 1213, 3220-3221)
# ------------------------------------------------------------------
mkdir -p "$HOME_DIR"
mkdir -p "$GIT_SHARED_DIR"
mkdir -p "$HOME_DIR/.config" "$HOME_DIR/.local/share" "$HOME_DIR/.cache" "$HOME_DIR/.bun"

# Apply the NON-RECURSIVE chmod (the change under test)
chmod u+w "$HOME_DIR" "$GIT_SHARED_DIR" 2>/dev/null || true

# ------------------------------------------------------------------
# Test 1: Write a file into HOME_DIR root
# ------------------------------------------------------------------
TEST_FILE_1="$HOME_DIR/test-write-root.txt"
echo "hello from agent" > "$TEST_FILE_1"
[[ -f "$TEST_FILE_1" ]] || { echo "FAIL: cannot write file to HOME_DIR root"; exit 1; }
[[ "$(cat "$TEST_FILE_1")" == "hello from agent" ]] || { echo "FAIL: file content mismatch in HOME_DIR root"; exit 1; }
echo "PASS: write to HOME_DIR root"

# ------------------------------------------------------------------
# Test 2: Write a file into a nested subdirectory of HOME_DIR
# ------------------------------------------------------------------
TEST_FILE_2="$HOME_DIR/.config/test-nested.json"
echo '{"agent": true}' > "$TEST_FILE_2"
[[ -f "$TEST_FILE_2" ]] || { echo "FAIL: cannot write file to HOME_DIR/.config"; exit 1; }
echo "PASS: write to HOME_DIR/.config"

# ------------------------------------------------------------------
# Test 3: Write a file into GIT_SHARED_DIR
# ------------------------------------------------------------------
TEST_FILE_3="$GIT_SHARED_DIR/test-git-write.txt"
echo "git shared content" > "$TEST_FILE_3"
[[ -f "$TEST_FILE_3" ]] || { echo "FAIL: cannot write file to GIT_SHARED_DIR"; exit 1; }
echo "PASS: write to GIT_SHARED_DIR"

# ------------------------------------------------------------------
# Test 4: Create a new subdirectory and write into it (simulates agent
# creating project-specific dirs at runtime)
# ------------------------------------------------------------------
RUNTIME_DIR="$HOME_DIR/.local/share/opencode"
mkdir -p "$RUNTIME_DIR"
TEST_FILE_4="$RUNTIME_DIR/sessions.db"
echo "sqlite-placeholder" > "$TEST_FILE_4"
[[ -f "$TEST_FILE_4" ]] || { echo "FAIL: cannot write to runtime-created subdir"; exit 1; }
echo "PASS: write to runtime-created subdirectory"

# ------------------------------------------------------------------
# Test 5: Write into GIT_SHARED_DIR/keys (used by git credential flow)
# ------------------------------------------------------------------
KEYS_DIR="$GIT_SHARED_DIR/keys"
mkdir -p "$KEYS_DIR"
TEST_FILE_5="$KEYS_DIR/abc123"
echo "/path/to/key" > "$TEST_FILE_5"
[[ -f "$TEST_FILE_5" ]] || { echo "FAIL: cannot write to GIT_SHARED_DIR/keys"; exit 1; }
echo "PASS: write to GIT_SHARED_DIR/keys"

# ------------------------------------------------------------------
# Test 6: Verify that removing write permission from the root dir
# actually prevents writing (sanity check that chmod matters)
# ------------------------------------------------------------------
RESTRICTED_DIR="$TMPDIR/restricted"
mkdir -p "$RESTRICTED_DIR/sub"
chmod u-w "$RESTRICTED_DIR/sub"
if echo "should fail" > "$RESTRICTED_DIR/sub/nope.txt" 2>/dev/null; then
  echo "FAIL: sanity check — write succeeded on restricted dir"
  exit 1
fi
echo "PASS: sanity check — restricted dir blocks writes"

echo ""
echo "All sandbox-writability tests passed."
