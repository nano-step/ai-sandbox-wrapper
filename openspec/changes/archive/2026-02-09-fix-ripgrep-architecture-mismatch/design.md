## Context

OpenCode uses ripgrep (`rg`) for fast file searching, which powers the "@" file reference feature. The current sandbox architecture mounts the host's `~/.local/share/opencode` directory into the container to persist OpenCode's data. This includes `~/.local/share/opencode/bin/rg`, which is a platform-specific binary.

**Current State:**
- Host (macOS): OpenCode downloads macOS Mach-O binary for `rg`
- Container (Linux ARM64): Attempts to execute macOS binary → ENOEXEC error
- Result: All file search operations fail silently or with cryptic errors

**Constraints:**
- Cannot change how OpenCode bundles its binaries (upstream project)
- Must maintain the volume mount for OpenCode data persistence
- Solution must work across all host platforms (macOS Intel, macOS ARM, Linux)

## Goals / Non-Goals

**Goals:**
- Provide a working ripgrep binary inside the container regardless of host platform
- Minimal change to existing infrastructure
- No impact on container startup time or image size (within reason)

**Non-Goals:**
- Modifying OpenCode's binary bundling behavior
- Creating platform-specific container images
- Implementing a general solution for all architecture-mismatched binaries

## Decisions

### Decision 1: Install ripgrep via apt in base image

**Choice:** Add `ripgrep` to the apt-get install list in `dockerfiles/base/Dockerfile`

**Rationale:**
- Ripgrep is available in Debian bookworm repositories
- Single-line change, minimal complexity
- Package manager handles architecture automatically
- Consistent with existing pattern (other tools installed via apt)

**Alternatives Considered:**
1. **Download binary at container startup** - Rejected: Adds startup latency, requires network, more complex
2. **Exclude bin/ from volume mount** - Rejected: May break other OpenCode functionality that depends on bundled tools
3. **Symlink at startup** - Rejected: Requires entrypoint modification, race conditions possible

### Decision 2: Rely on PATH ordering for binary resolution

**Choice:** System ripgrep at `/usr/bin/rg` will be found before OpenCode's bundled version because:
- OpenCode likely checks PATH or uses `which rg`
- `/usr/bin` is typically early in PATH
- If OpenCode uses absolute path to its bundled binary, the ENOEXEC error will still occur, but this is an upstream issue

**Rationale:**
- No additional configuration needed
- Standard Unix behavior
- If OpenCode hardcodes the path, we'd need to file an upstream issue anyway

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| OpenCode may hardcode path to bundled rg | Test after implementation; file upstream issue if needed |
| Version mismatch between system rg and expected version | Ripgrep has stable CLI; unlikely to cause issues |
| Image size increase | Ripgrep is ~2-3MB; acceptable trade-off for functionality |
| Future OpenCode updates may change binary location | Monitor OpenCode releases; current solution is defensive |

## Migration Plan

1. **Update Dockerfile**: Add `ripgrep` to apt-get install line
2. **Rebuild base image**: `bash lib/install-base.sh`
3. **Rebuild OpenCode image**: `bash lib/install-opencode.sh`
4. **Test**: Run `ai-run opencode` and verify "@" file search works
5. **Rollback**: Remove `ripgrep` from Dockerfile and rebuild (simple revert)

No data migration required. Change is purely additive.
