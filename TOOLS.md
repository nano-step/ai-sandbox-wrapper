# Supported Tools

This document covers all AI coding tools supported by the sandbox beyond OpenCode.

## CLI Tools

| Tool | Status | Install Type | Description |
|------|--------|--------------|-------------|
| **claude** | ✅ | Native binary | Anthropic Claude Code |
| **opencode** | ✅ | Native Go | Open-source AI coding (see [README.md](README.md)) |
| **gemini** | ✅ | npm/Node | Google Gemini CLI (free tier) |
| **aider** | ✅ | Python | AI pair programmer (Git-native) |
| **kilo** | ✅ | npm/Node | Kilo Code (500+ models) |
| **codex** | ✅ | npm/Node | OpenAI Codex agent |
| **amp** | ✅ | npm/Node | Sourcegraph Amp |
| **qwen** | ✅ | npm/Node | Alibaba Qwen CLI (1M context) |
| **droid** | ✅ | Custom | Factory CLI |
| **qoder** | ✅ | npm/Node | Qoder AI assistant |
| **auggie** | ✅ | npm/Node | Augment Auggie |
| **codebuddy** | ✅ | npm/Node | Tencent CodeBuddy |
| **jules** | ✅ | npm/Node | Google Jules |
| **shai** | ✅ | npm/Node | OVHcloud SHAI |

> **Note:** GUI tools (VSCode, codeserver) have been removed in v2.0.1. Use your native IDE with AI tools running in the sandbox.

## Pre-Built Images

All tools are available as pre-built images from GitLab Container Registry:

```bash
# Pull specific tool images
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-claude:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-gemini:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-aider:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-kilo:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-codex:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-amp:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-qwen:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-droid:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-qoder:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-auggie:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-codebuddy:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-jules:latest
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-shai:latest

# Or let setup.sh pull them automatically
./setup.sh  # Select tools, images will be pulled if available
```

## Tool-Specific Configuration

### Claude

**Native Config:** `~/.config/claude/`
**Project Config:** `.claude.json`

```bash
# Run Claude
ai-run claude

# Example project config
cat > .claude.json << 'EOF'
{
  "model": "sonnet-4-20250514",
  "max_output_tokens": 8192,
  "temperature": 0.7
}
EOF
```

**API Key:** `ANTHROPIC_API_KEY` in `~/.ai-sandbox/env`

### Gemini

**Native Config:** `~/.config/gemini/`
**Project Config:** `.gemini.json`

```bash
# Run Gemini
ai-run gemini
```

**API Key:** `GOOGLE_API_KEY` in `~/.ai-sandbox/env` (optional, free tier available)

### Aider

**Native Config:** `~/.config/aider/`
**Project Config:** `.aider.conf`

```bash
# Run Aider
ai-run aider
```

**API Key:** `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` in `~/.ai-sandbox/env`

### Amp (Sourcegraph)

**Native Config:** `~/.config/amp/`
**Project Config:** `.amp.json`

```bash
# Run Amp
ai-run amp
```

### Kilo Code

**Native Config:** `~/.config/kilo/`

```bash
# Run Kilo
ai-run kilo
```

**API Key:** Supports 500+ models, configure via tool

### Codex

**Native Config:** `~/.config/codex/`

```bash
# Run Codex
ai-run codex
```

**API Key:** `OPENAI_API_KEY` in `~/.ai-sandbox/env`

### Qwen

**Native Config:** `~/.config/qwen/`

```bash
# Run Qwen
ai-run qwen
```

**Features:** 1M context window

### Other Tools

All other tools follow similar patterns:
- Native config in `~/.config/{tool}/`
- Run with `ai-run {tool}`
- API keys in `~/.ai-sandbox/env`

## Per-Project Configuration

All tools support project-specific config files that override global settings:

| Tool | Project Config | Native Global Config |
|------|----------------|----------------------|
| Claude | `.claude.json` | `~/.config/claude/` |
| Gemini | `.gemini.json` | `~/.config/gemini/` |
| Aider | `.aider.conf` | `~/.config/aider/` |
| Opencode | `.opencode.json` | `~/.config/opencode/` |
| Amp | `.amp.json` | `~/.config/amp/` |

**Priority:** Project config > Native Global config > Container defaults

## Additional Container Tools

During setup, you can optionally install additional tools into the base Docker image:

### AI Enhancement Tools

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

### Language Runtimes

| Runtime | Description | Size Impact |
|---------|-------------|-------------|
| ruby | Ruby 3.3.0 + Rails 8.0.2 (via rbenv) | ~500MB |

**Ruby/Rails** is useful when:
- Developing Ruby on Rails applications
- Running Rails generators and migrations
- Using Bundler for dependency management
- Building Ruby-based APIs and web apps

### Always Installed

- `typescript` + `typescript-language-server` - Required for AI coding assistants with LSP integration

### Manual Installation

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

## Known Issues

### Native Tool Config Compatibility

In v2.1.0+, tool configurations are **directly bind-mounted** from your host. This ensures 100% compatibility with your native tool settings and authentications.

1. **Host Config**: `~/.config/<tool>/` or `~/.<tool>/`
2. **Container Mount**: `/home/agent/.config/<tool>` (Automatic)

**Currently Supported for Direct Mount:**
- ✅ All tools listed above

Please [open an issue](https://github.com/kokorolx/ai-sandbox-wrapper/issues) if you encounter problems with specific tools.

### Tool-Specific Issues

**"BunInstallFailedError"** (Resolved in v2.1.0)
- This was caused by stale caches. We now use **Cache Isolation** via anonymous volumes.
- If you still see this, run `./setup.sh --no-cache` to force a clean build.

**Tool doesn't start**
- Check if you selected the tool during setup
- Look for the Docker image: `docker images | grep ai-`
- Verify API keys are configured in `~/.ai-sandbox/env`

## Tool-Specific Config Locations

All tool configs are consolidated under `~/.ai-sandbox/tools/{tool}/home/`:

```
~/.ai-sandbox/tools/{tool}/home/
├── .config/          # Tool configuration
│   └── {tool}/       # Per-tool config directory
├── .local/share/     # Tool data (cache, sessions)
├── .cache/           # Runtime cache
└── .{tool}/          # Tool-specific directories
```

Each tool's config is mounted to `/home/agent/` inside the container.

## View Tool Configuration

```bash
# View configuration paths for a specific tool
npx @kokorolx/ai-sandbox-wrapper config tool claude

# View configuration content
npx @kokorolx/ai-sandbox-wrapper config tool claude --show
```

## Common Usage Patterns

### Running Tools

```bash
# Direct mode (default)
ai-run claude
ai-run gemini
ai-run aider

# Shell mode (interactive)
ai-run claude --shell
ai-run gemini -s

# With port exposure
ai-run claude --expose 3000
ai-run aider -e 3000,5555

# With network access
ai-run claude -n metamcp_metamcp-network
ai-run gemini -n network1,network2
```

### API Key Configuration

All tools use the same `~/.ai-sandbox/env` file:

```bash
# Edit environment file
nano ~/.ai-sandbox/env
```

Add keys in format: `KEY_NAME=value`
```bash
# Claude
ANTHROPIC_API_KEY=sk-ant-api03-...

# OpenAI-based tools (Codex, Aider, etc.)
OPENAI_API_KEY=sk-...

# Gemini (optional, free tier available)
GOOGLE_API_KEY=AIza...
```

### Workspace and Git Access

All tools share the same workspace and Git access configuration:

```bash
# Workspace management
npx @kokorolx/ai-sandbox-wrapper workspace add ~/projects/my-app

# Git access management
npx @kokorolx/ai-sandbox-wrapper git enable ~/projects/myrepo
```

See [README.md](README.md) for detailed configuration instructions.
