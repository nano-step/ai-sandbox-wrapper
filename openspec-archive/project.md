# Project Context

## Purpose
Docker-based security sandbox for AI coding agents. Isolates AI tools (Claude, Gemini, Aider, OpenCode, etc.) from the host system by running them in containers with strict access controls. Protects SSH keys, API tokens, and sensitive data while allowing AI tools to work on whitelisted project directories only.

**Key Goals:**
- Prevent AI agents from accessing sensitive host data (SSH keys, browser data, env vars)
- Whitelist-only workspace access (explicit opt-in per directory)
- Support 15+ AI coding tools with consistent security model
- Easy setup via interactive installer or npx

## Tech Stack
- **Shell Scripts (Bash)** - Primary language for all tooling (~95% of codebase)
- **Docker** - Container runtime for isolation
- **Node.js** - CLI entry point (`bin/cli.js`) and npm package distribution
- **Bun** - Runtime inside containers (ai-base image)
- **GitLab CI** - Automated image builds and registry hosting

## Project Conventions

### Code Style
- **Shell scripts**: Always start with `#!/usr/bin/env bash` and `set -e`
- **Error handling**: Use `set -e` for fail-fast behavior
- **Quoting**: Always quote variables (`"$VAR"` not `$VAR`)
- **Naming**: 
  - Install scripts: `lib/install-{tool}.sh`
  - Dockerfiles: `dockerfiles/{tool}/Dockerfile`
  - Executables: `bin/{command}`
- **Comments**: Use `#` for inline comments, document non-obvious logic
- **Terminal UI**: Use `tput` for colors and cursor control in interactive menus

### Architecture Patterns
1. **Layered Docker Images**
   - Base image (`ai-base`) provides Bun runtime and common dependencies
   - Tool images extend base with tool-specific installations
   
2. **Workspace Whitelisting**
   - `~/.ai-workspaces` contains allowed directories (one per line)
   - `ai-run` validates current directory against whitelist before execution
   
3. **Security-First Design**
   - CAP_DROP=ALL - no elevated privileges
   - Read-only filesystem except `/workspace`
   - Non-root user (`agent`) inside containers
   - Opt-in Git/SSH access per workspace

4. **Configuration Hierarchy**
   - Project config (`.{tool}.json`) > Global config (`~/.ai-home/{tool}/`) > Container defaults

### Testing Strategy
- **Shell syntax validation**: `bash -n` for all `.sh` files
- **Node.js validation**: `node --check` for JS files
- **CI verification**: Each tool image tested with `--version` or `--help` after build
- **No unit test framework** - validation is syntax + smoke tests

### Git Workflow
- **Main branch**: `master`
- **Development branch**: `beta` (CI builds triggered here)
- **Commit style**: Conventional commits preferred (`feat:`, `fix:`, `docs:`)
- **CI triggers**: Image rebuilds on changes to `lib/install-*.sh` or `dockerfiles/*/Dockerfile`

## Domain Context
- **AI Coding Tools**: CLI-based AI assistants that can read/write code (Claude Code, Aider, Gemini CLI, etc.)
- **Container Isolation**: Docker provides process and filesystem isolation
- **Workspace**: A directory the user explicitly allows AI tools to access
- **SSH Key Selector**: Interactive prompt letting users choose which SSH keys to share with containers

## Important Constraints
- **Security is non-negotiable**: Never mount full home directory, never share SSH keys by default
- **Interactive prompts**: Setup must work in TTY; non-interactive mode fails securely
- **Cross-platform**: Must work on macOS (Intel + Apple Silicon), Linux (x64 + ARM64), Windows (WSL2)
- **No network access to host**: Containers cannot reach host services by default
- **Opt-in only**: Git credentials, SSH keys, and API keys require explicit user consent

## External Dependencies
- **Docker Engine/Desktop**: Required runtime (user must install separately)
- **GitLab Container Registry**: `registry.gitlab.com/kokorolee/ai-sandbox-wrapper/` hosts pre-built images
- **npm Registry**: Package published as `@nano-step/ai-sandbox-wrapper`
- **GitHub**: Source repository at `github.com/nano-step/ai-sandbox-wrapper`
- **Tool-specific APIs**: Each AI tool may require its own API key (Anthropic, OpenAI, Google, etc.)
