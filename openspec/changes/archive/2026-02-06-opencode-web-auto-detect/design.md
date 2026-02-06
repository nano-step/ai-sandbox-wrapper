## Context

The `ai-run` script currently handles port exposure via the `PORT` environment variable (lines 1217-1242). Users must manually coordinate three settings when running OpenCode's web interface:
1. `PORT=4096` - expose the port to host
2. `--port 4096` - tell OpenCode which port to use
3. `--hostname 0.0.0.0` - bind to all interfaces (required for container access)

The flag parsing architecture (lines 7-33) uses a simple while loop with case statement. Flags like `--shell` and `--network` are parsed before tool arguments, with remaining args collected into `TOOL_ARGS` array.

**Existing patterns to leverage:**
- Multi-value parsing: `IFS=',' read -ra ARRAY <<< "$value"`
- Warning style: `echo "⚠️ WARNING: ..."`
- Docker arg building: accumulate into string variable (e.g., `NETWORK_OPTIONS`)

## Goals / Non-Goals

**Goals:**
- Add `--expose` flag as primary port exposure mechanism
- Auto-detect `opencode web` command and extract `--port` value
- Automatically inject `--hostname 0.0.0.0` when web command detected
- Combine manual (`--expose`) and auto-detected ports without duplicates
- Maintain backward compatibility with `PORT` env var (with deprecation notice)
- Display helpful URL message when web server starts

**Non-Goals:**
- Supporting web detection for all tools (only OpenCode initially, extensible later)
- Changing `PORT_BIND` behavior (remains as-is)
- Auto-detecting ports from other flags like `--listen` or `-p` (future enhancement)
- Persisting port configuration to config.json (use flags per-run)

## Decisions

### Decision 1: Flag Placement in Parsing Order

**Choice:** Add `--expose/-e` to existing flag parsing block (lines 13-32)

**Rationale:** Follows established pattern. Flags before tool name are ai-run flags; flags after go to TOOL_ARGS.

**Alternatives considered:**
- New parsing phase after TOOL_ARGS collection → Rejected: breaks convention, confusing UX
- Environment variable only → Rejected: user explicitly wants flag-based API

### Decision 2: Web Command Detection Location

**Choice:** Insert detection logic at line ~1216, after all config setup but before PORT_MAPPINGS construction

**Rationale:** 
- TOOL_ARGS is fully populated by this point
- Can modify/augment TOOL_ARGS before Docker invocation
- PORT_MAPPINGS construction can use combined ports

**Flow:**
```
Flag parsing (7-33) → Config setup (35-1215) → Web detection (NEW) → Port mapping (1217+) → Docker run
```

### Decision 3: Port Combination Strategy

**Choice:** Use a bash associative array to deduplicate ports from multiple sources

**Rationale:** Simple, no external dependencies, handles duplicates naturally

```bash
declare -A EXPOSE_PORTS_MAP
# Add from --expose flag
# Add from PORT env var (with deprecation warning)
# Add from auto-detected --port in TOOL_ARGS
# Convert back to array for iteration
```

**Alternatives considered:**
- Simple array with grep dedup → Works but messier
- Sort -u → Requires subshell, changes order

### Decision 4: Hostname Injection Approach

**Choice:** Scan TOOL_ARGS for `--hostname`, inject `--hostname 0.0.0.0` if not present when web command detected

**Rationale:** User-specified hostname takes precedence; only inject default when needed

```bash
# Pseudo-code
if web_detected && ! contains_hostname; then
  TOOL_ARGS+=("--hostname" "0.0.0.0")
fi
```

### Decision 5: Default Port for OpenCode Web

**Choice:** Default to port 4096 when `opencode web` detected without `--port`

**Rationale:** OpenCode's documented default behavior. User can override with `--port`.

### Decision 6: Deprecation Strategy for PORT Variable

**Choice:** Show warning on first use, continue to work indefinitely

**Rationale:** 
- Breaking change is disruptive for existing scripts/workflows
- Warning educates users about new preferred method
- No removal timeline needed for simple env var

```bash
if [[ -n "${PORT:-}" ]]; then
  echo "⚠️  WARNING: PORT environment variable is deprecated. Use --expose flag instead."
  # Still process it...
fi
```

## Risks / Trade-offs

### Risk 1: TOOL_ARGS Parsing Complexity
**Risk:** Parsing `--port` from TOOL_ARGS may break if tool uses non-standard flag format
**Mitigation:** Only parse well-known patterns (`--port`, `--port=`). Unknown formats pass through unchanged.

### Risk 2: Port Conflicts
**Risk:** Auto-detected port may conflict with manually exposed port or host service
**Mitigation:** Docker will fail with clear error. User can adjust. No silent failures.

### Risk 3: Hostname Injection Side Effects
**Risk:** Injecting `--hostname 0.0.0.0` may not work for all tools
**Mitigation:** Only inject for known tools (OpenCode). Extensible via tool-specific config later.

### Trade-off: Implicit vs Explicit Behavior
**Trade-off:** Auto-detection is convenient but "magic" behavior can surprise users
**Mitigation:** Always print what was auto-detected: `🌐 Detected web command. Auto-exposing port 4096.`

## Implementation Approach

### Phase 1: Add --expose Flag
1. Add `--expose/-e` to flag parsing case statement
2. Refactor PORT_MAPPINGS to use `EXPOSE_PORTS` array
3. Add deprecation warning for `PORT` env var
4. Update debug output

### Phase 2: Web Command Detection
1. Add `detect_opencode_web()` function
2. Parse `--port` value from TOOL_ARGS
3. Inject `--hostname 0.0.0.0` if needed
4. Add detected port to EXPOSE_PORTS
5. Print user-friendly URL message

### Phase 3: Documentation
1. Update README port exposure section
2. Add examples for new `--expose` flag
3. Document web auto-detection behavior
