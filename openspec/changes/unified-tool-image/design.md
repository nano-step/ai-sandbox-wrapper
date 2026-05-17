## Context

Currently the sandbox builds one Docker image per AI tool: `ai-base:latest` → `ai-claude:latest`, `ai-opencode:latest`, etc. Each `install-{tool}.sh` generates a `dockerfiles/{tool}/Dockerfile` and runs `docker build`. The `ai-run` wrapper resolves `ai-{tool}:latest` at runtime.

Users already select tools via a multi-select menu in `setup.sh`. The difference is that today each selection triggers a separate image build. The new approach composes all selected tools into a single image.

Key constraint: the existing `install-{tool}.sh` scripts contain both Dockerfile generation logic AND `docker build` invocation. These need to be separated.

## Goals / Non-Goals

**Goals:**
- User selects tools from multi-select menu → one `ai-sandbox:latest` image is built with all selected tools
- `ai-run` defaults to shell mode — all installed tools available as commands
- `ai-run {tool}` still works as a shortcut (overrides entrypoint)
- Existing tool install scripts are refactored minimally — extract Dockerfile snippets, keep backward compatibility
- Setup remembers which tools were installed (for rebuild/update scenarios)

**Non-Goals:**
- Hot-adding tools without rebuild (out of scope — requires image rebuild)
- Running multiple tools simultaneously in one container (each `ai-run` is still one container)
- Changing the security model (same non-root user, same CAP_DROP, same workspace whitelisting)
- Supporting both per-tool images AND unified image simultaneously (unified replaces per-tool)

## Decisions

### 1. Snippet extraction pattern

**Decision**: Each `install-{tool}.sh` gains a `dockerfile_snippet()` function that echoes Dockerfile `RUN` lines. A new `lib/build-sandbox.sh` calls each selected tool's snippet function and composes the final Dockerfile.

**Why not a separate snippet file per tool?** Keeping the snippet in the install script avoids file proliferation and keeps tool-specific logic co-located. The install script can still be run standalone for debugging.

**Pattern:**
```bash
# In install-{tool}.sh
dockerfile_snippet() {
  cat <<'SNIPPET'
USER root
RUN mkdir -p /usr/local/lib/gemini && \
    cd /usr/local/lib/gemini && \
    bun init -y && \
    bun add @google/gemini-cli && \
    ln -s /usr/local/lib/gemini/node_modules/.bin/gemini /usr/local/bin/gemini
USER agent
SNIPPET
}

# When sourced with SNIPPET_MODE=1, only export the function
if [[ "${SNIPPET_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

# Otherwise, run the full install (legacy behavior)
# ... existing build logic ...
```

### 2. Unified Dockerfile composition

**Decision**: `lib/build-sandbox.sh` generates `dockerfiles/sandbox/Dockerfile` by:
1. Starting with the base image preamble (from `install-base.sh`)
2. Appending each selected tool's snippet in sequence
3. Ending with the non-root user setup and `CMD ["bash"]` (no ENTRYPOINT)

**Why `CMD ["bash"]` instead of ENTRYPOINT?** Shell-first UX. `docker run ai-sandbox:latest` opens bash. `docker run ai-sandbox:latest claude` runs claude. This is the standard Docker pattern for multi-command images.

### 3. Image naming

**Decision**: `ai-sandbox:latest`. The name clearly communicates "this is the sandbox image" without implying a specific tool.

**Alternative considered**: `ai-all:latest` — rejected because not all tools are installed, only selected ones.

### 4. Tool selection persistence

**Decision**: Save selected tools to `~/.ai-sandbox/config.json` under a new `tools.installed` array. This allows:
- `ai-run` to know which tools are available (for help text, validation)
- Rebuild with same selections (`setup.sh` pre-selects previously installed tools)
- Future `ai-run --add-tool` capability

### 5. `ai-run` changes

**Decision**: Minimal changes to `ai-run`:
- Image resolution: always use `ai-sandbox:latest` (or `registry.gitlab.com/.../ai-sandbox:latest` for registry mode)
- No tool argument → shell mode (already exists as `--shell`, just make it the default when no tool specified)
- Tool argument → `--entrypoint {tool}` override (e.g., `ai-run claude` → `docker run --entrypoint claude ai-sandbox:latest`)
- Tool-specific config mounts (the `case "$TOOL"` block) still work — `TOOL` is still parsed from `$1`
- Remove the image-per-tool resolution: `IMAGE="ai-${TOOL}:latest"` → `IMAGE="ai-sandbox:latest"`

### 6. `setup.sh` flow change

**Decision**: The tool selection menu stays the same (already multi-select). The change is in what happens after selection:
- Instead of looping through tools and calling `install-{tool}.sh` individually, call `build-sandbox.sh` once with the full tool list
- Enhancement tools, language runtimes, and MCP tools are still selected separately and passed as flags to the base image build (unchanged)

### 7. CI pipeline

**Decision**: `.gitlab-ci.yml` builds one `ai-sandbox:latest` image instead of N tool images. The build job accepts a `TOOLS` variable (comma-separated) to control which tools are included. Default: all tools.

## Risks / Trade-offs

**[Larger image size]** → Acceptable. Users choose which tools to install. A typical selection (2-3 tools) adds 200-500MB over base. Mitigation: show estimated size during selection.

**[Single build failure blocks all tools]** → Mitigation: build-sandbox.sh validates each snippet independently before composing. If one tool fails, report which one and offer to skip it.

**[Tool version conflicts]** → Low risk. Current tools install into isolated paths (`/usr/local/lib/{tool}`, `/usr/local/bin/{tool}`). Only risk is npm global conflicts. Mitigation: tools use `bun add` in isolated dirs, not `npm install -g`.

**[Breaking change for existing users]** → Users must re-run `setup.sh` to rebuild. Old `ai-{tool}:latest` images become orphaned. Mitigation: setup.sh detects old images and offers cleanup (`docker rmi ai-claude:latest ai-opencode:latest ...`).

**[Registry image strategy]** → Currently CI builds per-tool images. New approach builds one image with all tools (for registry). Users pulling from registry get all tools regardless of selection. Mitigation: acceptable for registry — it's a convenience feature, not a size-optimized path.

## Open Questions

1. Should `ai-run` validate that the requested tool is actually installed in the image? (e.g., `ai-run claude` when claude wasn't selected during setup) — Recommendation: yes, check `config.json` and warn.
2. Should we support `aider` (Python-based) in the unified image? It uses `pip install --break-system-packages` which could conflict. — Recommendation: yes, Python tools install into their own venvs, low conflict risk.
