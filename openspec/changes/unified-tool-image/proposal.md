## Why

Currently each AI tool (Claude, OpenCode, Gemini, Aider, etc.) is built as a separate Docker image (`ai-claude:latest`, `ai-opencode:latest`, etc.) on top of a shared base image. This means users must build 5-15 separate images during setup, `ai-run` resolves a different image per tool, and switching tools requires exiting one container and starting another. Users want a single container where all their selected tools are available — pick tools during setup, build one image, open a shell, and run any installed tool.

## What Changes

- **New build system**: `install-base.sh` (or a new `install-all.sh`) composes a single Dockerfile from user-selected tool snippets and builds one `ai-sandbox:latest` image
- **Multi-select tool menu in `setup.sh`**: Users pick which tools to install from a checklist; only selected tools are baked into the single image
- **Tool install scripts become snippet providers**: Each `install-{tool}.sh` gains a function/mode that returns its Dockerfile `RUN` lines instead of building a standalone image
- **`ai-run` runtime changes**: Uses `ai-sandbox:latest` instead of `ai-{tool}:latest`; defaults to shell mode; tool name becomes an optional entrypoint override (`ai-run claude` → runs claude directly inside the unified image)
- **Shell-first UX**: `ai-run` without a tool argument opens an interactive shell with all installed tools available
- **ENTRYPOINT removal**: The unified image has no fixed ENTRYPOINT; tools are invoked by name as commands
- **`ai-run {tool}` still works**: Overrides entrypoint to run the specified tool directly (backward-compatible CLI)
- **Per-tool images deprecated**: Individual `ai-{tool}:latest` images are no longer built by default

## Capabilities

### New Capabilities
- `unified-image-build`: Composable build system that generates a single Dockerfile from selected tool snippets and builds one `ai-sandbox:latest` image
- `tool-selection-menu`: Interactive multi-select menu in `setup.sh` for choosing which AI tools to include in the unified image
- `shell-first-runtime`: Updated `ai-run` that defaults to shell mode with all tools available, with optional direct tool invocation via `ai-run {tool}`

### Modified Capabilities
- `base-image`: Build script extended to accept and compose tool installation snippets into the base Dockerfile
- `container-runtime`: `ai-run` changes image resolution from `ai-{tool}:latest` to `ai-sandbox:latest`, defaults to shell mode, tool name becomes entrypoint override

## Impact

- **`lib/install-base.sh`**: Major changes — must accept tool selections and compose unified Dockerfile
- **`lib/install-{tool}.sh`** (all 14+ scripts): Each needs a snippet-provider mode that outputs Dockerfile lines without building
- **`dockerfiles/`**: New `dockerfiles/sandbox/Dockerfile` (generated); per-tool Dockerfiles become optional/legacy
- **`setup.sh`**: New multi-select tool menu replaces individual tool installation flow
- **`bin/ai-run`**: Image resolution logic changes; shell-first default; entrypoint override for direct tool invocation
- **`.gitlab-ci.yml`**: CI pipeline changes from building N tool images to building one unified image
- **`bin/cli.js`**: May need updates if it references per-tool image names
- **Cross-platform**: No new platform concerns — same Docker-based approach, just fewer images
- **Security**: No change to security model — same non-root user, same CAP_DROP, same workspace whitelisting
