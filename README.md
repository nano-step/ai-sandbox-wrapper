# 🔒 AI Sandbox Wrapper

**Isolate AI coding agents from your host system. Protect your data.**

AI coding tools like Claude, Gemini, and Aider have full access to your filesystem, environment variables, and terminal. This project sandboxes them in Docker containers with **strict security restrictions**.

**What this does:** Runs AI tools in secure containers that can only access specific project folders, protecting your SSH keys, API tokens, and other sensitive data.

**What you get:** Peace of mind using AI coding tools without risking your personal and system data.

*Last updated: Tuesday, February 3, 2026*

## ✨ New in v2.2.0: Clipboard Fixes & Screenshot Detection

The **v2.2.0 release** solves the "air-gap" problem for text copying and streamlines screenshot workflows.

-   ✅ **OSC 52 Clipboard Support**: Copy text from inside Linux containers directly to your macOS clipboard (works over SSH too!).
-   ✅ **Auto-Detect Screenshot Folder**: Automatically finds where your Mac saves screenshots and offers to whitelist it. No more permission errors when dragging images into AI tools.
-   ✅ **Seamless Drag & Drop**: Just drag screenshots into the terminal window.

## ✨ New in v2.1.0: Stability & Native Persistence

The **v2.1.0 release** focuses on architectural stability and a more intuitive persistence model.

-   ✅ **Stable Node 22 LTS**: Switched to a robust Node 22 base image for maximum compatibility and performance.
-   ✅ **Direct Mount Persistence**: Changes made *inside* the container (logins, settings, sessions) now save directly to your host's native folders.
-   ✅ **Cache Isolation**: Heavy caches (`node_modules`, `.npm`, `.cache`) are isolated using anonymous volumes to prevent "cache poisoning" and runtime conflicts.

### Native Config Mapping
Your tool configurations are now directly linked from your Mac/PC:
- Host: `~/.config/opencode` ↔ Container: `/home/agent/.config/opencode`
- Host: `~/.local/share/opencode` ↔ Container: `/home/agent/.local/share/opencode`

---

## ⚠️ Breaking Change: v2.0.0 - Config Directory Reorganization

**Version 2.0.0** reorganized the directory structure to a tool-centric layout and introduced a unified `config.json`.

## 🛡️ Why Use This?

Without sandbox:
- AI agents can read your SSH keys, API tokens, browser data
- Can execute arbitrary code with your user permissions
- Can access files outside your project

With AI Sandbox:
- ✅ AI only sees whitelisted workspace folders
- ✅ No access to host environment variables (API keys hidden)
- ✅ Read-only filesystem (except workspace)
- ✅ No network access to host services
- ✅ Runs as non-root user in container
- ✅ CAP_DROP=ALL (no elevated privileges)

## 🚀 Step-by-Step Installation

### Step 1: Prerequisites
Ensure you have Docker installed and running:
- **macOS:** [Install Docker Desktop](https://www.docker.com/products/docker-desktop) and start it
- **Linux:** Install Docker Engine with `curl -fsSL https://get.docker.com | sh`
- **Windows:** Use WSL2 with Docker Desktop

Verify Docker is working:
```bash
docker --version
docker ps  # Should not show errors
```

### Step 2: Run Setup

**Option A: Using npx (Recommended)**
```bash
npx @kokorolx/ai-sandbox-wrapper setup
```

**Option B: Clone and run manually**
```bash
git clone https://github.com/kokorolx/ai-sandbox-wrapper.git
cd ai-sandbox-wrapper
./setup.sh
```

**Fresh build (no Docker cache):**
```bash
npx @kokorolx/ai-sandbox-wrapper setup --no-cache
# or
./setup.sh --no-cache
```

### Step 3: Follow the Interactive Prompts
1. **Whitelist workspaces (Optional)** - Enter directories AI tools can access, or just hit **Enter** to whitelist on-demand later.
2. **Select tools** - Use arrow keys to move, space to select, Enter to confirm
3. **Choose image source** - Select registry (faster) or build locally

### Step 4: Complete Setup
```bash
# Reload your shell to update PATH
source ~/.zshrc

# Add your API keys (only if using tools that require them)
nano ~/.ai-sandbox/env  # Add ANTHROPIC_API_KEY, OPENAI_API_KEY, etc.
```

### Step 5: Run Your First Tool
```bash
# Navigate to a project directory that's in your whitelisted workspaces
cd ~/projects/my-project

# Run a tool (the example below assumes you selected Claude during setup)
claude --version  # or: ai-run claude --version
```

## 📋 What You Need

**Required:**
- **Docker** - Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- **Git** - For cloning the repository
- **Bash** - For running the setup script

**Optional (for specific tools):**
- **Python 3** - For tools like Aider
- **SSH keys** - For Git access in containers

## ✅ After Installation

### Verify Everything Works
```bash
# Reload your shell to get the new commands
source ~/.zshrc

# Check if the main command works
ai-run --help

# Test a tool you installed (replace 'claude' with your chosen tool)
claude --version
```

### Add More Projects Later (Optional)
If you want to give AI access to more project directories later:
```bash
# Add a new workspace
echo '/path/to/new/project' >> ~/.ai-sandbox/workspaces

# View current allowed directories
cat ~/.ai-sandbox/workspaces
```

### Configure API Keys (If Needed)
Some tools require API keys to work properly:
```bash
nano ~/.ai-sandbox/env
```
Then add your keys in the format: `KEY_NAME=your_actual_key_here`
Examples:
- `ANTHROPIC_API_KEY=your_key_here` (for Claude)
- `OPENAI_API_KEY=your_key_here` (for OpenAI tools)

## 🐳 Using Pre-Built Images

**Skip the build process!** Pull pre-built images directly from GitLab Container Registry:

```bash
# Pull a specific tool image
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-claude:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-gemini:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-aider:latest

# Or let setup.sh pull them automatically
./setup.sh  # Select tools, images will be pulled if available
```

**Available pre-built images:**
- `ai-base:latest` - Base image with Node.js 22 LTS runtime
- `ai-amp:latest` - Sourcegraph Amp
- `ai-claude:latest` - Claude Code CLI
- `ai-droid:latest` - Factory CLI
- `ai-gemini:latest` - Google Gemini CLI
- `ai-kilo:latest` - Kilo Code (500+ models)
- `ai-codex:latest` - OpenAI Codex
- `ai-aider:latest` - AI pair programmer
- `ai-opencode:latest` - Open-source AI coding
- `ai-qwen:latest` - Alibaba Qwen (1M context)
- `ai-qoder:latest` - Qoder AI assistant
- `ai-auggie:latest` - Augment Auggie
- `ai-codebuddy:latest` - Tencent CodeBuddy
- `ai-jules:latest` - Google Jules
- `ai-shai:latest` - OVHcloud SHAI

**Benefits:**
- ⚡ **Faster setup** - No build time (seconds vs minutes)
- ✅ **CI-tested** - All images verified in GitLab CI
- 🔄 **Auto-updated** - Latest versions on every push to beta branch

## 📦 Supported Tools

### CLI Tools (Terminal-based)

| Tool | Status | Install Type | Description |
|------|--------|--------------|-------------|
| **claude** | ✅ | Native binary | Anthropic Claude Code |
| **opencode** | ✅ | Native Go | Open-source AI coding |
| **gemini** | ✅ | npm/Node | Google Gemini CLI (free tier) |
| **aider** | ✅ | Python | AI pair programmer (Git-native) |
| **kilo** | ✅ | npm/Node | Kilo Code (500+ models) |
| **codex** | ✅ | npm/Node | OpenAI Codex agent |
| **amp** | ✅ | npm/Node | Sourcegraph Amp |
| **qwen** | ✅ | npm/Node | Alibaba Qwen CLI (1M context) |
| **droid** | ✅ | Custom | Factory CLI |

> **Note:** GUI tools (VSCode, codeserver) have been removed in v2.0.1. Use your native IDE with AI tools running in the sandbox.

## ⚠️ Known Issues

### Native Tool Config Compatibility

In v2.1.0+, tool configurations are **directly bind-mounted** from your host. This ensures 100% compatibility with your native tool settings and authentications.

1. **Host Config**: `~/.config/<tool>/` or `~/.<tool>/`
2. **Container Mount**: `/home/agent/.config/<tool>` (Automatic)

**Currently Supported for Direct Mount:**
- ✅ `claude`
- ✅ `opencode`
- ✅ `amp`
- ✅ `gemini`
- ✅ `aider`
- ... and all other supported tools.

Please [open an issue](https://github.com/kokorolx/ai-sandbox-wrapper/issues) if you encounter problems with specific tools.

## 🖥️ Platform Support

| Platform | Status |
|----------|--------|
| macOS (Intel) | ✅ |
| macOS (Apple Silicon) | ✅ |
| Linux (x64) | ✅ |
| Linux (ARM64) | ✅ |
| Windows (Docker Desktop + WSL2) | ✅ |

## 📁 Directory Structure

AI Sandbox Wrapper creates and manages a single consolidated directory in your home folder:

| Directory | Purpose | Contents |
|-----------|---------|----------|
| `~/bin/` | Executables | `ai-run` wrapper and symlinks to tool scripts |
| `~/.ai-sandbox/` | All config | Consolidated configuration directory (see structure below) |
| `~/.ai-images/` | Local images | Locally built Docker images (if not using registry) |

### Sandbox Structure

```
~/.ai-sandbox/
├── config.json      # Unified config (workspaces, git, networks)
├── tools/           # Isolated sandbox environments
│   └── <tool>/
│       └── home/    # Sandbox home directory (excludes native configs)
├── shared/          # Shared assets
│   └── git/         # Shared git config and keys
└── env              # API keys (format: KEY=value)
```

**Note:** Tools also bind-mount your **native** `~/.config/<tool>` directories for persistence.

### Key Files

| File | Purpose |
|------|---------|
| `~/.ai-sandbox/config.json` | Unified config (workspaces, git access, networks) |
| `~/.ai-sandbox/env` | API keys (format: `KEY=value`, one per line) |
| `~/.ai-sandbox/workspaces` | Legacy workspace file (fallback) |
| `~/.ai-sandbox/git-allowed` | Legacy git-allowed file (fallback) |

## ⚙️ Configuration

### Tool-Specific Configuration

Each tool has its own persistent home directory inside `~/.ai-sandbox/tools/<tool>/home/`.

```bash
# View configuration paths for a specific tool (Recommended)
npx @kokorolx/ai-sandbox-wrapper config tool claude

# View configuration content
npx @kokorolx/ai-sandbox-wrapper config tool claude --show
```

### API Keys
```bash
# Edit environment file
nano ~/.ai-sandbox/env
```

### Workspace Management
```bash
# CLI commands (recommended)
npx @kokorolx/ai-sandbox-wrapper workspace list
npx @kokorolx/ai-sandbox-wrapper workspace add ~/projects/my-new-app
npx @kokorolx/ai-sandbox-wrapper workspace remove ~/old-project

# Interactive menu
npx @kokorolx/ai-sandbox-wrapper update

# Legacy (still works)
echo '/path/to/project' >> ~/.ai-sandbox/workspaces
cat ~/.ai-sandbox/workspaces
```

### Git Access Management
```bash
# CLI commands
npx @kokorolx/ai-sandbox-wrapper git status
npx @kokorolx/ai-sandbox-wrapper git enable ~/projects/myrepo
npx @kokorolx/ai-sandbox-wrapper git disable ~/projects/myrepo

# Interactive menu
npx @kokorolx/ai-sandbox-wrapper update
```

### Network Configuration

AI containers can join Docker networks to communicate with other services (databases, APIs, MetaMCP).

#### Runtime Selection (Recommended)

```bash
# Interactive network selection
ai-run opencode -n

# Direct network specification
ai-run opencode -n metamcp_metamcp-network
ai-run opencode -n network1,network2,network3
```

#### Saved Configuration

Network selections are saved to `~/.ai-sandbox/config.json`:
- **Per-workspace**: Saved for specific project directories
- **Global**: Default for all workspaces

```bash
# CLI commands
npx @kokorolx/ai-sandbox-wrapper network list
npx @kokorolx/ai-sandbox-wrapper network add mynetwork --global
npx @kokorolx/ai-sandbox-wrapper network add dev-network --workspace ~/projects/myapp
npx @kokorolx/ai-sandbox-wrapper network remove mynetwork --global

# View current config
npx @kokorolx/ai-sandbox-wrapper config show
npx @kokorolx/ai-sandbox-wrapper config show --json

# Example config.json structure (v2)
{
  "version": 2,
  "workspaces": ["/Users/you/projects/my-app"],
  "git": {
    "allowedWorkspaces": ["/Users/you/projects/my-repo"],
    "keySelections": {}
  },
  "networks": {
    "global": ["shared-services"],
    "workspaces": {
      "/Users/you/projects/my-app": ["my-app_default", "redis_network"]
    }
  }
}
```

#### Without `-n` Flag

When running without the flag, saved networks are used silently:
- Workspace-specific config takes priority
- Falls back to global config
- Non-existent networks are skipped silently

### Environment Variables

All environment variables are configured in `~/.ai-sandbox/env` or passed at runtime:

#### Image Source
Choose between locally built images or pre-built GitLab registry images:

```bash
# Add to ~/.ai-sandbox/env

# Use locally built images (default)
AI_IMAGE_SOURCE=local

# Use pre-built images from GitLab registry
AI_IMAGE_SOURCE=registry
```

Or run with environment variable:
```bash
AI_IMAGE_SOURCE=registry ai-run claude
```

#### Platform Selection
For ARM64 Macs or other platforms, specify the container platform:

```bash
# Run with specific platform (linux/arm64, linux/amd64)
AI_RUN_PLATFORM=linux/arm64 ai-run claude
```

#### Docker Connection
For remote Docker hosts or non-default configurations:

```bash
# Use a different Docker socket
export DOCKER_HOST=unix:///var/run/docker.sock

# Or TCP connection
export DOCKER_HOST=tcp://localhost:2375
```

#### Port Exposure
Expose container ports to the host for web development, APIs, and dev servers:

```bash
# Expose a single port (localhost only - secure default)
PORT=3000 ai-run opencode

# Expose multiple ports
PORT=3000,5555,5556,5557 ai-run opencode

# Expose to network (use with caution)
PORT=3000 PORT_BIND=all ai-run opencode
```

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `PORT` | Comma-separated ports | (none) | Ports to expose (e.g., `3000,5555`) |
| `PORT_BIND` | `localhost`, `all` | `localhost` | Bind to localhost only or all interfaces |

**Security Notes:**
- Default binding is `127.0.0.1` (localhost only) - only accessible from your machine
- Using `PORT_BIND=all` exposes ports to your network - a warning is displayed
- Invalid port numbers (outside 1-65535) are skipped with a warning

**Example: Rails Development**
```bash
# Start container with Rails default port exposed
PORT=3000 ai-run opencode --shell

# Inside container, start Rails server
rails server -b 0.0.0.0

# Access from host browser at http://localhost:3000
```

#### API Keys
Configure in `~/.ai-sandbox/env`:

```bash
# Required for Claude tools
ANTHROPIC_API_KEY=sk-ant-api03-...

# Required for OpenAI-based tools
OPENAI_API_KEY=sk-...

# Optional for Gemini CLI
GOOGLE_API_KEY=AIza...

# Optional: disable specific keys
# ANTHROPIC_API_KEY=
# OPENAI_API_KEY=

### Per-Project Config

Each tool supports project-specific config files that override global settings. These files are located in your workspace and are accessible to the tool:

| Tool | Project Config | Native Global Config |
|------|----------------|----------------------|
| Claude | `.claude.json` | `~/.config/claude/` |
| Gemini | `.gemini.json` | `~/.config/gemini/` |
| Aider | `.aider.conf` | `~/.config/aider/` |
| Opencode | `.opencode.json` | `~/.config/opencode/` |
| Amp | `.amp.json` | `~/.config/amp/` |

**Persistence:** Since v2.1.0, changes to global settings *inside* the container are automatically saved back to your **Native Global Config** on the host.

**Priority:** Project config > Native Global config > Container defaults

```bash
# Example: Project-specific Claude config
cat > .claude.json << 'EOF'
{
  "model": "sonnet-4-20250514",
  "max_output_tokens": 8192,
  "temperature": 0.7
}
EOF
```

### Tool-Specific Config Locations

All tool configs are consolidated under `~/.ai-sandbox/home/{tool}/`:

```
~/.ai-sandbox/home/{tool}/
├── .config/          # Tool configuration
│   └── {tool}/       # Per-tool config directory
├── .local/share/     # Tool data (cache, sessions)
├── .cache/           # Runtime cache
└── .claude/          # Claude-specific (for claude tool)
```

Each tool's config is mounted to `/home/agent/` inside the container.

### Additional Tools (Container-Only)

During setup, you can optionally install additional tools into the base Docker image. Tools are organized into two categories:

#### AI Enhancement Tools

| Tool | Description | Size Impact |
|------|-------------|-------------|
| spec-kit | Spec-driven development toolkit | ~50MB |
| ux-ui-promax | UI/UX design intelligence tool | ~30MB |
| openspec | OpenSpec - spec-driven development | ~20MB |
| playwright | Browser automation with Chromium/Firefox/WebKit | ~500MB |

**Playwright** is useful when AI tools need to:
- Run browser-based tests
- Scrape web content
- Verify UI changes
- Automate browser workflows

#### Language Runtimes

| Runtime | Description | Size Impact |
|---------|-------------|-------------|
| ruby | Ruby 3.3.0 + Rails 8.0.2 (via rbenv) | ~500MB |

**Ruby/Rails** is useful when:
- Developing Ruby on Rails applications
- Running Rails generators and migrations
- Using Bundler for dependency management
- Building Ruby-based APIs and web apps

#### Always Installed

- `typescript` + `typescript-language-server` - Required for AI coding assistants with LSP integration

#### Manual Installation

```bash
# Manual build with Playwright (if not selected during setup)
INSTALL_PLAYWRIGHT=1 bash lib/install-base.sh

# Manual build with Ruby/Rails (if not selected during setup)
INSTALL_RUBY=1 bash lib/install-base.sh

# Verify Playwright in container
docker run --rm ai-base:latest npx playwright --version

# Verify Ruby/Rails in container
docker run --rm ai-base:latest ruby --version
docker run --rm ai-base:latest rails --version

# Verify TypeScript LSP
docker run --rm ai-base:latest tsc --version
```

### Git Workflow
AI tools work **inside** containers without Git credentials by default (secure).

**Option 1: Secure (Default) - Review & Commit from Host**
```bash
# 1. AI tool makes changes
ai-run claude  # Edits files in your workspace

# 2. Review changes on host
git diff

# 3. Commit from host (you have full control)
git add .
git commit -m "feat: changes suggested by AI"
git push
```

**Option 2: Enable Git Access (Interactive Prompt)**
When you run an AI tool, you'll be prompted:
```
🔐 Git Access Control
Allow AI tool to access Git credentials for this workspace?

  1) Yes, allow once (this session only)
  2) Yes, always allow for this workspace
  3) No, keep Git disabled (secure default)
```

**Managing Git access:**
```bash
# View allowed workspaces
cat ~/.ai-sandbox/git-allowed

# Remove a workspace from allowed list
nano ~/.ai-sandbox/git-allowed  # Delete the line
```

**Why this is secure:**
- ✅ Opt-in per workspace (not global)
- ✅ Granular control: Only selected keys and their matching Host configs are shared
- ✅ SSH keys mounted read-only
- ✅ You control which projects get Git access
- ✅ Easy to revoke access anytime

## 🔐 Security Model

```
┌─────────────────────────────────────────────────┐
│                   HOST SYSTEM                    │
│  ❌ SSH keys, API tokens, browser data          │
│  ❌ Home directory, system files                │
│  ❌ Other projects                               │
└─────────────────────────────────────────────────┘
                        │
                   Docker isolation
                        │
┌─────────────────────────────────────────────────┐
│              AI SANDBOX CONTAINER               │
│  ✅ /workspace (whitelisted folders only)       │
│  ✅ Passed API keys (explicit, for API calls)   │
│  ✅ Git config (for commits)                    │
│  ❌ Everything else                              │
└─────────────────────────────────────────────────┘
```

## ❓ Troubleshooting

### Common Issues

**Docker not found**
- Make sure Docker Desktop is installed and running
- Check with: `docker --version` and `docker ps`

**"command not found: ai-run"**
- Reload your shell: `source ~/.zshrc`
- Verify setup completed: check if `~/bin/ai-run` exists

**"Workspaces not configured"** (Legacy)
- Note: This error is resolved in v2.1.0+.
- Run setup again: `./setup.sh` or simply run an AI tool in your project folder to trigger interactive whitelisting.

**"BunInstallFailedError"** (Resolved in v2.1.0)
- This was caused by stale caches. We now use **Cache Isolation** via anonymous volumes. If you still see this, run `./setup.sh --no-cache` to force a clean build.

**Tool doesn't start**
- Check if you selected the tool during setup
- Look for the Docker image: `docker images | grep ai-`

**"Outside whitelisted workspace" error**
- Add your current directory: `echo "$(pwd)" >> ~/.ai-sandbox/workspaces`
- Or navigate to a directory you whitelisted during setup

**API key errors**
- Check your keys in: `cat ~/.ai-sandbox/env`
- Make sure keys are in format: `KEY_NAME=actual_key_value`

### Getting Help

If you're still having issues:
1. Check that Docker is running
2. Re-run `./setup.sh` to reinstall
3. Look at the configuration files in `~/.ai-sandbox/`:
   - `~/.ai-sandbox/workspaces` - should contain your project directories
   - `~/.ai-sandbox/env` - should contain your API keys (if needed)
4. View Docker images: `docker images` to see if tools built successfully

## 📚 Quick Reference

### Main Commands
- `ai-run <tool>` - Run any tool in sandbox (e.g., `ai-run claude`)
- `ai-run <tool> --shell` - Start interactive shell mode (see [Shell Mode Guide](SHELL-MODE-USAGE.md))
- `<tool>` - Shortcut for tools you installed (e.g., `claude`, `aider`)

### Execution Modes

**Direct Mode (Default):**
```bash
ai-run opencode
# Tool runs directly, exits on Ctrl+C
```

**Shell Mode (Interactive):**
```bash
ai-run opencode --shell  # or -s
# Starts bash shell, run tool manually
# Ctrl+C stops tool only, not container
# Perfect for development and debugging
```

See [SHELL-MODE-USAGE.md](SHELL-MODE-USAGE.md) for detailed examples and use cases.

### Configuration Files
- `~/.ai-sandbox/env` - Store API keys here
- `~/.ai-sandbox/workspaces` - Whitelisted project directories
- `~/.ai-sandbox/cache/` - Tool cache (persistent)
- `~/.ai-sandbox/home/` - Tool configurations (persistent)

### Common Tasks
```bash
# Add a new project directory to AI access
echo '/path/to/my/new/project' >> ~/.ai-sandbox/workspaces

# Check what tools are installed
ls ~/bin/

# Reload shell after setup
source ~/.zshrc

# Update to latest version
npx @kokorolx/ai-sandbox-wrapper@latest setup

# Clean up caches and configs
npx @kokorolx/ai-sandbox-wrapper clean
```

### Cleanup Command

The `clean` command provides an interactive way to remove AI Sandbox directories:

```bash
npx @kokorolx/ai-sandbox-wrapper clean
```

**Features:**
- Two-level menu: First select category, then specific tools/items
- Shows directory sizes before deletion
- Groups items by risk level (🟢 Safe, 🟡 Medium, 🔴 Critical)
- Requires typing "yes" to confirm deletion

**Categories:**
| Category | Contents | Risk |
|----------|----------|------|
| Tool caches | `~/.ai-sandbox/cache/{tool}/` | 🟢 Safe to delete |
| Tool configs | `~/.ai-sandbox/home/{tool}/` | 🟡 Loses settings |
| Global config | `~/.ai-sandbox/workspaces`, `~/.ai-sandbox/env`, etc. | 🟡🔴 Mixed |
| Everything | `~/.ai-sandbox/` | 🔴 Full reset |

**Example:**
```
🧹 AI Sandbox Cleanup

What would you like to clean?
  1. Tool caches (~/.ai-sandbox/cache/) - Safe to delete
  2. Tool configs (~/.ai-sandbox/home/) - Loses settings
  3. Global config files - Loses preferences
  4. Everything (~/.ai-sandbox/) - Full reset

Enter selection (or 'q' to quit): 1

📁 Tool Caches (~/.ai-sandbox/cache/)

Select tools to clear:
  1. claude/ (45.2 MB)
  2. opencode/ (120.5 MB)

Enter selection (comma-separated, 'all', or 'b' to go back): 1

You are about to delete:
  - ~/.ai-sandbox/cache/claude/ (45.2 MB)

Total: 45.2 MB

Type 'yes' to confirm: yes

✓ Deleted ~/.ai-sandbox/cache/claude/

Deleted 1 items, freed 45.2 MB
```

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📝 License

MIT
