
# AI Sandbox Wrapper - Project Knowledge Base

**Generated:** 2025-01-23
**Branch:** Not in git repo context
**Purpose:** Docker-based security sandbox for AI coding agents

## Overview

Security-focused wrapper that runs AI coding tools (Claude, Gemini, Aider, etc.) in isolated Docker containers with strict access controls. Protects host system by whitelisting only specific workspace directories.

## Structure

```
./
├── bin/              # Executable wrappers (ai-run, setup-ssh-config)
├── lib/              # Installation scripts for 15+ AI tools
├── dockerfiles/      # Container images for each tool
├── setup.sh          # Main setup script (interactive)
├── .opencode/        # OpenCode configuration
├── .specify/         # Spec-driven development config
└── .github/          # GitHub workflows
```

## Where to Look

| Task | Location | Notes |
|------|----------|-------|
| Main setup | `setup.sh` | Interactive installer, handles all setup |
| Add new tool | `lib/install-{tool}.sh` | Follow pattern: `install-tool.sh` |
| Container image | `dockerfiles/{tool}/Dockerfile` | Each tool has dedicated Dockerfile |
| Run tool sandbox | `bin/ai-run` | Entry point for all sandboxed tools |

## Code Map

**Key Executables:**

| File | Purpose | Lines |
|------|---------|-------|
| `bin/ai-run` | Main wrapper, handles Docker run commands | ~400 |
| `setup.sh` | Interactive installer with menu system | ~600 |
| `lib/ssh-key-selector.sh` | SSH key management for Git access | ~150 |
| `lib/install-tool.sh` | Template for new tool installations | ~100 |

## Conventions

- **Shell scripts:** Use `set -e` for error handling
- **Dockerfiles:** Multi-stage builds, non-root user (`agent`)
- **Naming:** `install-{tool}.sh` for tool installers
- **Exit codes:** Scripts return non-zero on failure

## Anti-Patterns (This Project)

- ❌ **NEVER** run AI tools without Docker isolation
- ❌ **NEVER** mount full home directory to containers
- ❌ **NEVER** share SSH keys by default (opt-in only)
- ❌ **NEVER** allow network access to host services

## Unique Styles

1. **Interactive menus** in setup.sh using tput for terminal control
2. **Workspace whitelisting** via `~/.ai-sandbox/workspaces` file
3. **Per-tool Docker images** - each AI tool has dedicated container
4. **SSH key selector** - user chooses which keys to share per workspace
5. **Image source selection** - local build vs. GitLab registry
6. **Consolidated config** - all config in `~/.ai-sandbox/` directory

## Commands

```bash
# Setup (run once)
./setup.sh

# Run AI tool in sandbox
ai-run claude
claude --version  # If symlinked during setup

# Add new workspace
echo '/path/to/project' >> ~/.ai-sandbox/workspaces

# Configure API keys
nano ~/.ai-sandbox/env
```

## Security Model

- Containers run as non-root `agent` user
- CAP_DROP=ALL - no elevated privileges
- Read-only filesystem except `/workspace`
- Only whitelisted directories accessible
- API keys passed via environment (explicit opt-in)
- Git access: opt-in per workspace, key-level control

## Docker Network Support

**MetaMCP and multi-container setups:**
- Join networks at runtime using the `-n` / `--network` flag
- Enables `host.docker.internal` for host service access
- See [METAMCP_GUIDE.md](METAMCP_GUIDE.md) for detailed integration instructions

### Container Naming

Containers are automatically named based on the project folder:

```bash
# Running in /Users/tamlh/projects/my-awesome-app
$ ai-run opencode
# Creates container: opencode-my-awesome-app

# Running in /Users/tamlh/workspace/Test Project
$ ai-run claude
# Creates container: claude-test-project
```

**Naming format:** `{tool}-{sanitized_folder_name}`

**Rules:**
- Folder name sanitized (lowercase, alphanumeric, hyphens, underscores)
- Max 50 characters
- Spaces converted to hyphens
- Special characters removed

### Network Management Commands

```bash
# Interactive network selection
ai-run opencode -n

# Direct network specification
ai-run opencode -n metamcp_metamcp-network
ai-run opencode -n network1,network2

# Saved networks config
cat ~/.ai-sandbox/config.json

# List AI tool containers (named by project folder)
docker ps --filter "name=opencode-" --filter "name=claude-"
```

## Gotchas

- Requires Docker running before setup
- Must run `source ~/.zshrc` after setup to get `ai-run` in PATH
- API keys not passed to containers unless in `~/.ai-sandbox/env`
- Git access requires explicit user permission per workspace
- Dockerfiles use Bun runtime by default (ai-base image)
