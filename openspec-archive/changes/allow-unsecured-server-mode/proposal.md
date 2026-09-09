## Why

When running `opencode web` or `opencode serve` via `ai-run` in non-interactive mode (e.g., CI/CD, scripts, Docker Compose), users face two issues:

1. **No easy way to set password**: The only way to set `OPENCODE_SERVER_PASSWORD` is via environment variable in `~/.ai-sandbox/env`, which requires manual file editing. There's no CLI flag to pass the password directly.

2. **Unnecessary warnings for intentional unsecured mode**: The system shows "OPENCODE_SERVER_PASSWORD not set - server is unsecured" even when unsecured mode is intentional for localhost-only development. This creates log noise and implies the user is doing something wrong.

Per [official OpenCode documentation](https://opencode.ai/docs/server/):
> "Set `OPENCODE_SERVER_PASSWORD` to protect the server with HTTP basic auth... This applies to both `opencode serve` and `opencode web`."

And from the [Web docs](https://opencode.ai/docs/web/):
> "If `OPENCODE_SERVER_PASSWORD` is not set, the server will be unsecured. This is fine for local use but should be set for network access."

The wrapper should provide convenient CLI flags to match OpenCode's native authentication model.

## What Changes

### Password Configuration
- Add `--password <value>` / `-p <value>` flag to set `OPENCODE_SERVER_PASSWORD` directly from CLI
- Add `--password-env <VAR>` flag to read password from a custom environment variable
- Password is passed to the container via `-e OPENCODE_SERVER_PASSWORD=<value>`

### Unsecured Mode
- Add `--allow-unsecured` flag to explicitly opt-in to unsecured server mode
- When flag is provided, suppress the warning message entirely
- Without the flag, keep existing behavior (show warning in non-interactive mode)

### Documentation
- Update `ai-run --help` to document new flags
- Document when unsecured mode is acceptable (localhost, development, trusted networks)
- Add examples for common use cases (CI/CD, Docker Compose, scripts)

## Capabilities

### New Capabilities

- `server-auth-flags`: CLI flags for OpenCode server authentication control:
  - `--password <value>` / `-p <value>`: Set server password directly
  - `--password-env <VAR>`: Read password from specified environment variable  
  - `--allow-unsecured`: Explicitly allow unsecured mode without warnings

### Modified Capabilities

- `container-runtime`: Extend `bin/ai-run` to handle new authentication flags when OpenCode web/serve mode is detected (lines ~1118-1188)

## Impact

- **Code**: `bin/ai-run` - add flag parsing, password handling, and conditional warning suppression
- **CLI**: Three new flags for `ai-run opencode web/serve` commands
- **Documentation**: Update help text and README with authentication options
- **Security**: No reduction in security - all options are explicit opt-in
- **Backward Compatibility**: No breaking changes - existing behavior preserved when flags are omitted
