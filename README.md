# 🔒 AI Sandbox Wrapper

**Run OpenCode and other AI coding agents in secure Docker containers.**

Protect your SSH keys, API tokens, and system files while using AI tools that need filesystem access.

*Last updated: February 25, 2026*

---

## 📑 Table of Contents

- [What's New](#-whats-new)
- [Why Use This?](#️-why-use-this)
- [Quick Start](#-quick-start)
- [Configuration](#️-configuration)
  - [API Keys](#api-keys)
  - [Workspaces](#workspaces)
  - [Port Exposure](#port-exposure)
  - [Server Authentication](#server-authentication)
  - [Network Access](#network-access)
  - [Git Access](#git-access)
  - [Clipboard](#clipboard)
- [Directory Structure](#-directory-structure)
- [Security Model](#-security-model)
- [Quick Reference](#-quick-reference)
- [Troubleshooting](#-troubleshooting)
- [Other Tools](#-other-tools)
- [Contributing](#-contributing)
- [License](#-license)

---

## ✨ What's New

### 📦 Package moved to `@nano-step` scope

This project is now published as **`@nano-step/ai-sandbox-wrapper`**. The old `@kokorolx/ai-sandbox-wrapper` package is deprecated and will no longer receive updates.

```bash
# Old (deprecated)
npx @kokorolx/ai-sandbox-wrapper setup

# New
npx @nano-step/ai-sandbox-wrapper setup
```

If you have the old package globally installed, uninstall it:
```bash
npm uninstall -g @kokorolx/ai-sandbox-wrapper
```

### v2.7.0: Git Fetch-Only Mode & Bundled Skills

- **Git Fetch-Only**: Allow git fetch/pull but block push — perfect for AI agents that should read but not write
- **Bundled Skills**: RTK token optimizer skills auto-installed for OpenCode users
- **SSH Config Fix**: Resolved crash during git credential setup

```bash
# Fetch-only mode (no push allowed)
opencode --git-fetch

# Or select from interactive menu:
#   4) Fetch only - allow once (no push, this session)
#   5) Fetch only - always for this workspace (no push)

# Manage via CLI
npx @nano-step/ai-sandbox-wrapper git fetch-only ~/projects/myrepo
npx @nano-step/ai-sandbox-wrapper git full ~/projects/myrepo
npx @nano-step/ai-sandbox-wrapper git status
```

---

## 🛡️ Why Use This?

| Without Sandbox | With AI Sandbox |
|-----------------|-----------------|
| AI reads SSH keys, API tokens | ✅ Only whitelisted folders visible |
| Full filesystem access | ✅ Read-only except workspace |
| Host environment exposed | ✅ API keys passed explicitly |
| Runs with your permissions | ✅ Non-root, CAP_DROP=ALL |

---

## 🚀 Quick Start

**Prerequisites:** Docker Desktop (macOS/Windows) or Docker Engine (Linux)

```bash
# Install
npx @nano-step/ai-sandbox-wrapper setup

# Reload shell
source ~/.zshrc

# Run OpenCode
opencode
```

During setup: select **opencode**, choose registry images (faster), whitelist your project directories.

---

## ⚙️ Configuration

### API Keys

```bash
nano ~/.ai-sandbox/env
```
```
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
```

### Workspaces

```bash
npx @nano-step/ai-sandbox-wrapper workspace add ~/projects/my-app
# Or: echo '/path/to/project' >> ~/.ai-sandbox/workspaces
```

### Port Exposure

```bash
# New --expose flag (recommended)
opencode --expose 3000
opencode -e 3000,5555,5556

# Expose to network
PORT_BIND=all opencode --expose 3000

# Legacy (deprecated)
PORT=3000 opencode
```

**Web Mode Auto-Detection:**
```bash
opencode web                    # Auto-exposes 4096
opencode web --port 8080        # Auto-exposes 8080
opencode --expose 3000 web      # Exposes both 3000 and 4096
```

Output:
```
🌐 Detected web command. Auto-exposing port 4096.
🔌 Port mappings: 4096
🌐 Web UI available at http://localhost:4096
```

### Server Authentication

Control authentication for OpenCode web server:

```bash
# Set password directly (visible in process list)
ai-run opencode web --password mysecret
ai-run opencode web -p mysecret

# Read password from environment variable (more secure)
MY_PASS=secret ai-run opencode web --password-env MY_PASS

# Explicitly allow unsecured mode (suppresses warning)
ai-run opencode web --allow-unsecured
```

**Login credentials:**
- Username: `opencode` (default, override with `OPENCODE_SERVER_USERNAME` env var)
- Password: your configured password

**Precedence:** `--password` > `--password-env` > `OPENCODE_SERVER_PASSWORD` env > interactive prompt

Without flags, interactive mode shows a menu; non-interactive mode shows a security warning.

**Port Conflict Detection:**
```
❌ ERROR: Port 3000 is already in use by node (PID: 12345)
```

### Network Access

```bash
# Join Docker networks (for databases, APIs, MetaMCP)
opencode -n mynetwork
opencode -n network1,network2
```

### Git Access

Git credentials are **not** shared by default. When you run a tool, you'll be prompted:
```
🔐 Git Access Control
  1) Yes, allow once
  2) Yes, always allow for this workspace
  3) No, keep Git disabled (secure default)
  4) Fetch only - allow once (no push, this session)
  5) Fetch only - always for this workspace (no push)
```

**Fetch-only mode** allows `git fetch`, `git pull`, `git clone` but blocks `git push`. Uses git's `pushInsteadOf` config — no network restrictions needed.

```bash
# Force fetch-only via flag
opencode --git-fetch

# Manage via CLI
npx @nano-step/ai-sandbox-wrapper git fetch-only ~/projects/myrepo
npx @nano-step/ai-sandbox-wrapper git full ~/projects/myrepo
```

### Nano-brain Auto-Repair

When running nano-brain inside the sandbox, `ai-run` performs a targeted preflight and automatic retry for common native-module failures (for example tree-sitter binding issues).

It also suppresses known **non-fatal** tree-sitter symbol-graph warnings when the command succeeds, so normal query output stays clean. To see suppressed diagnostics, run with debug mode (`AI_RUN_DEBUG=1`).

This behavior applies to both:
- direct mode (`ai-run npx nano-brain ...`)
- interactive shell mode (`ai-run`, then run `npx nano-brain ...` inside the container shell)

```bash
# Auto-repair enabled by default
ai-run npx nano-brain status

# Disable per-command
ai-run npx nano-brain status --no-nano-brain-auto-repair

# Disable via environment variable
AI_RUN_DISABLE_NANO_BRAIN_AUTO_REPAIR=1 ai-run npx nano-brain status

# Show suppressed non-fatal warning details
AI_RUN_DEBUG=1 ai-run npx nano-brain query "hello"
```

### Clipboard

Clipboard access in containers requires a terminal that supports **OSC52** protocol.

**Supported terminals:** iTerm2, Warp, Kitty, Alacritty, WezTerm, Windows Terminal, Ghostty

**Not supported:** GNOME Terminal, VS Code Terminal, Tilix, Terminator

Test if your terminal supports clipboard:
```bash
printf "\033]52;c;$(printf "test" | base64)\a"
# Press Cmd+V / Ctrl+V - if you see "test", it works
```

📖 **Full details:** [CLIPBOARD_SUPPORT.md](CLIPBOARD_SUPPORT.md)

### MCP Tools (Browser Automation)

During setup, you can optionally install MCP servers for AI agent browser automation:

| Tool | Maintainer | Features | Size |
|------|------------|----------|------|
| **Chrome DevTools MCP** | Google | Performance profiling, Core Web Vitals, detailed console/network inspection | ~400MB |
| **Playwright MCP** | Microsoft | Multi-browser (Chromium), TypeScript code generation, vision mode | ~300MB |

After installation, configure your MCP client (e.g., OpenCode) to use them:

**`~/.config/opencode/opencode.json`:**
```json
{
  "mcp": {
    "chrome-devtools": {
      "type": "local",
      "command": [
        "chrome-devtools-mcp",
        "--headless",
        "--isolated",
        "--executablePath", "/opt/chromium",
        "--chromeArg=--no-sandbox",
        "--chromeArg=--disable-setuid-sandbox"
      ]
    },
    "playwright": {
      "type": "local",
      "command": [
        "npx", "@playwright/mcp@latest",
        "--headless",
        "--browser", "chromium",
        "--no-sandbox"
      ]
    }
  }
}
```

> **Note:** The `--no-sandbox` flags are required when running in Docker containers. This is safe because the container itself provides isolation.

### Bundled Skills (OpenCode)

OpenCode containers auto-install these skills on first run (existing skills are never overwritten):

| Skill | Description |
|-------|-------------|
| `rtk` | Command reference for RTK token optimizer (60-90% token savings) |
| `rtk-setup` | Persistent RTK enforcement — updates AGENTS.md and propagates to subagents |

Skills are copied to `~/.config/opencode/skills/` and available immediately.

### Pre-built Images from ghcr.io

Skip the 10-20 minute local build by pulling pre-built `ai-opencode` images from GitHub Container Registry. Default pull target is **`ghcr.io/nano-step/ai-opencode:base`**.

```bash
# Default pull — :base variant
AI_IMAGE_SOURCE=registry ai-run opencode

# :full variant (superset of base; see comparison below)
AI_IMAGE_SOURCE=registry AI_IMAGE_TAG=full ai-run opencode

# Pin to a specific version (semver from package.json)
AI_IMAGE_SOURCE=registry AI_IMAGE_TAG=base-v5.1.3 ai-run opencode

# Pin to an exact commit
AI_IMAGE_SOURCE=registry AI_IMAGE_TAG=base-sha-2e6a0c4 ai-run opencode

# Override the registry entirely (e.g. fall back to GitLab)
AI_IMAGE_SOURCE=registry \
  AI_IMAGE_REGISTRY=registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-sandbox \
  AI_IMAGE_TAG=latest \
  ai-run opencode
```

**Environment variables**:
- `AI_IMAGE_SOURCE=registry` — opt in to registry pull (default: `local`, builds locally).
- `AI_IMAGE_REGISTRY` — override registry path (default: `ghcr.io/nano-step/ai-opencode`).
- `AI_IMAGE_TAG` — choose preset or pinned version (default: `base`).

**Tag formats**:
- `<preset>` — rolling latest (e.g. `:base`, `:full`). **← `ai-run` default = `:base`.**
- `<preset>-sha-<short>` — immutable per commit (e.g. `:base-sha-2e6a0c4`).
- `<preset>-v<version>` — semver from `package.json` (e.g. `:base-v5.1.3`).

#### Image contents — what's inside each variant

Both variants share the **same base layer** (Node 22, Bun, pnpm, Python 3 + pipx + uv, ripgrep, fd, tmux, vim, gh CLI, TypeScript/Python LSP servers, PDF/OCR tools, build-essential). They differ only in the opt-in `INSTALL_*` flags layered on top.

| Component | `:base` (~2.3 GB) | `:full` (~2.7 GB) |
|---|:---:|:---:|
| `opencode` binary (ENTRYPOINT) | ✅ | ✅ |
| **Coding helpers** | | |
| spec-kit (`specify`) | ✅ | ✅ |
| ux-ui-promax (`uipro`) | ✅ | ✅ |
| OpenSpec CLI (`openspec`) | ✅ | ✅ |
| RTK (token optimizer) + OpenCode skills `rtk`, `rtk-setup` | ✅ | ✅ |
| Atlassian CLI (`acli`) | ✅ | ✅ |
| **Observability** | | |
| Datadog Pup CLI + OpenCode skill `dd-pup` | ✅ | ✅ |
| **Language toolchains** | | |
| Go 1.23 + `sqlc`, `goose`, `golangci-lint` | ✅ | ✅ |
| Ruby + Rails | ❌ | ❌ |
| **Browser tools** | | |
| chrome-devtools-mcp (host CDP mode) | ✅ | ✅ |
| @playwright/mcp (host CDP mode) | ✅ | ✅ |
| Chromium binary in container | ❌ (host mode) | ❌ (host mode) |
| Playwright npm + browsers (standalone) | ❌ | ✅ |
| **Open Design** | | |
| `od-status` / `od-health` helper scripts | ❌ | ✅ |

**Practical guidance:**

- **`:base` (default)** — pick this for normal OpenCode usage. It has every tool needed for coding, code review, observability work, and MCP browser automation against host Chrome.
- **`:full`** — pick this if you also need to run standalone Playwright scripts inside the container (e.g. `npx playwright test`) or use the Open Design daemon helpers.

Neither variant ships Chromium **inside** the container — both MCP browser tools (chrome-devtools-mcp, playwright-mcp) connect to **host Chrome over CDP**. You must configure `mcp.chromePath` in `~/.ai-sandbox/config.json` for browser MCP to work.

The exact preset definitions live in [`ci/presets/base.env`](./ci/presets/base.env) and [`ci/presets/full.env`](./ci/presets/full.env) — these are the source of truth for what each image ships. Adding a new tool to a preset requires editing one of these files (see [AGENTS.md](./AGENTS.md) "Adding a New Tool > Kind B").

---

## 📁 Directory Structure

```
~/.ai-sandbox/
├── config.json      # Workspaces, git, networks
├── env              # API keys
├── tools/           # Per-tool sandbox homes
│   └── opencode/home/
└── shared/git/      # Shared git credentials
```

Native configs are bind-mounted:
- `~/.config/opencode` ↔ `/home/agent/.config/opencode`
- `~/.local/share/opencode` ↔ `/home/agent/.local/share/opencode`

---

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
│  ✅ Passed API keys (explicit)                  │
│  ✅ Git config (opt-in per workspace)           │
│  ❌ Everything else                              │
└─────────────────────────────────────────────────┘
```

---

## 📚 Quick Reference

```bash
# Run OpenCode
opencode                      # Direct mode
opencode --shell              # Interactive shell
opencode web                  # Web UI mode

# Port exposure
opencode --expose 3000        # Expose port
opencode -e 3000,4000         # Multiple ports

# Network
opencode -n mynetwork         # Join Docker network

# Git fetch-only
opencode --git-fetch            # Fetch only (no push)

# Nano-brain
ai-run npx nano-brain status                      # With auto-repair
AI_RUN_DISABLE_NANO_BRAIN_AUTO_REPAIR=1 ai-run npx nano-brain status

# Management
npx @nano-step/ai-sandbox-wrapper workspace list
npx @nano-step/ai-sandbox-wrapper clean
```

---

## ❓ Troubleshooting

| Issue | Solution |
|-------|----------|
| `command not found: opencode` | Run `source ~/.zshrc` |
| `Outside whitelisted workspace` | `echo "$(pwd)" >> ~/.ai-sandbox/workspaces` |
| Port already in use | Stop the process or use different port |
| Docker not found | Install and start Docker Desktop |
| Clipboard not working | Use OSC52-compatible terminal. See [CLIPBOARD_SUPPORT.md](CLIPBOARD_SUPPORT.md) |
| nano-brain native binding/tree-sitter error | Fatal errors auto-repair and retry once by default; known non-fatal symbol-graph warnings are suppressed unless `AI_RUN_DEBUG=1` |

---

## 📦 Other Tools

This sandbox also supports **Claude, Gemini, Aider, Kilo, Codex, Amp, Qwen**, and more.

See [TOOLS.md](TOOLS.md) for the full list and tool-specific configuration.

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## 📝 License

MIT
