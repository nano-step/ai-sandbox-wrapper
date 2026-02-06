# 🔒 AI Sandbox Wrapper

**Run OpenCode and other AI coding agents in secure Docker containers.**

Protect your SSH keys, API tokens, and system files while using AI tools that need filesystem access.

*Last updated: February 6, 2026*

## ✨ New in v2.3.0-beta: Web Mode & Port Exposure

- **Web Auto-Detection**: `opencode web` automatically exposes port 4096 and injects `--hostname 0.0.0.0`
- **`--expose` Flag**: New way to expose ports (replaces deprecated `PORT` env var)
- **Port Conflict Detection**: Fails fast if port is already in use

```bash
# Web mode - automatic port exposure
opencode web

# Custom port
opencode web --port 8080

# Expose additional ports
opencode --expose 3000,5555 web
```

## 🛡️ Why Use This?

| Without Sandbox | With AI Sandbox |
|-----------------|-----------------|
| AI reads SSH keys, API tokens | ✅ Only whitelisted folders visible |
| Full filesystem access | ✅ Read-only except workspace |
| Host environment exposed | ✅ API keys passed explicitly |
| Runs with your permissions | ✅ Non-root, CAP_DROP=ALL |

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
```

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

# Management
npx @kokorolx/ai-sandbox-wrapper workspace list
npx @kokorolx/ai-sandbox-wrapper clean
```

## ❓ Troubleshooting

| Issue | Solution |
|-------|----------|
| `command not found: opencode` | Run `source ~/.zshrc` |
| `Outside whitelisted workspace` | `echo "$(pwd)" >> ~/.ai-sandbox/workspaces` |
| Port already in use | Stop the process or use different port |
| Docker not found | Install and start Docker Desktop |

## 📦 Other Tools

This sandbox also supports **Claude, Gemini, Aider, Kilo, Codex, Amp, Qwen**, and more.

See [TOOLS.md](TOOLS.md) for the full list and tool-specific configuration.

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## 📝 License

MIT
