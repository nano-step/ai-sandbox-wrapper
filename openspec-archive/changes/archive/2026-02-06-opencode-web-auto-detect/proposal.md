## Why

Running OpenCode's web interface in a container requires manual port configuration (`PORT=4096 ai-run opencode web --port 4096 --hostname 0.0.0.0`), which is cumbersome and error-prone. Additionally, the current `PORT` environment variable naming is confusing - it's used to expose container ports to the host, but conflicts conceptually with tool-specific `--port` flags. A clearer API with auto-detection provides a seamless experience.

## What Changes

### Port Exposure API Redesign
- **BREAKING**: Deprecate `PORT` environment variable in favor of `--expose` flag
- Add `--expose` / `-e` flag to `ai-run` for explicit port exposure: `ai-run opencode --expose 3000,5000`
- `PORT` env var continues to work (backward compatibility) but shows deprecation notice

### Web Command Auto-Detection
- Auto-detect when `opencode web` subcommand is invoked
- Parse `--port` flag from tool arguments and automatically add to exposed ports
- Automatically inject `--hostname 0.0.0.0` if not specified (required for container-to-host access)
- Display helpful message showing the web UI URL

### Combined Behavior
- Manual `--expose` ports + auto-detected `--port` are combined
- Example: `ai-run opencode --expose 3000,5000 web --port 4096` exposes ports 3000, 5000, AND 4096
- No duplicate port exposure if same port specified in both

### Port Conflict Detection
- Pre-check if requested ports are already in use before starting container
- Fail fast with helpful message showing which process is using the port
- Cross-platform support using `lsof` (macOS/Linux) with fallback to `netstat`

## Capabilities

### New Capabilities
- `web-command-detection`: Automatic detection and configuration of tool web server subcommands, including port parsing from `--port` flag, hostname injection, and automatic port exposure

### Modified Capabilities
- `container-runtime`: 
  - Add `--expose` flag as primary port exposure mechanism
  - Deprecate `PORT` env var (keep for backward compatibility)
  - Support combining manual and auto-detected ports
  - Add port conflict detection with fail-fast behavior

## Impact

- **Code**: `bin/ai-run` - Add `--expose` flag parsing, web command detection, port combination logic
- **User Experience**: 
  - Simple case: `ai-run opencode web` just works (auto-exposes default port 4096)
  - Custom port: `ai-run opencode web --port 8080` auto-exposes 8080
  - Multiple servers: `ai-run opencode --expose 3000,5000 web --port 4096` exposes all three
- **Backward Compatibility**: 
  - `PORT` env var still works, shows deprecation notice
  - `PORT_BIND` env var unchanged
- **Security**: Ports bound to localhost by default (same as existing behavior)
- **Documentation**: Update README port exposure section
