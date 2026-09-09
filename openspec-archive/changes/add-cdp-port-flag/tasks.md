## 1. Flag Parsing

- [x] 1.1 Add `--cdp-port` flag to the flag parsing loop (around line 500–516 in `bin/ai-run`) — shift, validate range 1–65535, store in `MANUAL_CDP_PORT` variable
- [x] 1.2 Add `CHROME_CDP_PORT` env var support — read from environment with `${CHROME_CDP_PORT:-}`, apply only if `MANUAL_CDP_PORT` is not set

## 2. Port Assignment Logic

- [x] 2.1 Modify port computation block (around line 1288–1293) to skip hash computation when `MANUAL_CDP_PORT` or `CHROME_CDP_PORT` is set — use the manual value instead
- [x] 2.2 Verify reuse-if-alive probe still works correctly with manual port (no code change needed, but confirm probe logic at line 1307 uses `$HOST_CHROME_CDP_PORT`)

## 3. Help Text

- [x] 3.1 Add `CHROME_CDP_PORT` to `--help-env` output (around line 86–88 in `bin/ai-run`) with description, default behavior, and valid range

## 4. Validation

- [x] 4.1 Run `bash -n bin/ai-run` to verify shell syntax
- [x] 4.2 Verify `--cdp-port` flag appears in `--help` output
- [x] 4.3 Verify `CHROME_CDP_PORT` appears in `--help-env` output

## 5. Bug Fix

- [x] 5.1 Fix precedence: line 1259 `MANUAL_CDP_PORT="${CHROME_CDP_PORT:-}"` was overwriting the flag value — changed to `[[ -z "${MANUAL_CDP_PORT:-}" ]] && MANUAL_CDP_PORT="${CHROME_CDP_PORT:-}"` so flag takes precedence
