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
npx @kokorolx/ai-sandbox-wrapper git fetch-only ~/projects/myrepo
npx @kokorolx/ai-sandbox-wrapper git full ~/projects/myrepo
npx @kokorolx/ai-sandbox-wrapper git status
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
npx @kokorolx/ai-sandbox-wrapper setup

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
npx @kokorolx/ai-sandbox-wrapper workspace add ~/projects/my-app
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
npx @kokorolx/ai-sandbox-wrapper git fetch-only ~/projects/myrepo
npx @kokorolx/ai-sandbox-wrapper git full ~/projects/myrepo
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

# Management
npx @kokorolx/ai-sandbox-wrapper workspace list
npx @kokorolx/ai-sandbox-wrapper clean
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
