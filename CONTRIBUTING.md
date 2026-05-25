# Contributing to AI Sandbox Wrapper

Thank you for your interest in contributing! This project aims to make AI coding tools safer by isolating them from host systems.

## 🎯 Project Goals

1. **Security first** - Protect user data from AI agents
2. **Easy to use** - Simple setup, minimal configuration
3. **Tool coverage** - Support all popular AI coding tools

## 🛠️ How to Contribute

### Adding a New CLI Tool

1. Create `lib/install-{toolname}.sh`:
```bash
#!/usr/bin/env bash
set -e

TOOL="{toolname}"
echo "Installing $TOOL..."

mkdir -p "$HOME/ai-images/$TOOL"
mkdir -p "$HOME/.ai-cache/$TOOL"
mkdir -p "$HOME/.ai-home/$TOOL"

cat <<'EOF' > "$HOME/ai-images/$TOOL/Dockerfile"
FROM ai-base:latest
USER root
RUN bun install -g {npm-package}
USER agent
ENTRYPOINT ["{entrypoint}"]
EOF

docker build -t "ai-$TOOL:latest" "$HOME/ai-images/$TOOL"
echo "✅ $TOOL installed"
```

2. Add to `setup.sh`:
   - Add to tool list in the menu
   - Add to regex validation
   - Add to case statement

3. Test the installation:
```bash
./setup.sh  # Select your tool
ai-run {toolname} --help
```

### Adding a GUI Tool

GUI tools are more complex. See `lib/install-vscode.sh` or `lib/install-codeserver.sh` as examples.

### Improving Security

Security improvements are always welcome:
- Better container isolation
- Reducing container permissions
- Auditing mounted volumes

## 📋 Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/add-new-tool`
3. Make your changes
4. Test locally with `./setup.sh`
5. Submit a pull request

## 🐛 Reporting Issues

Use the issue templates:
- **Bug Report** - Something isn't working
- **Feature Request** - Suggest a new tool or improvement
- **Security Issue** - Report privately via security@example.com

## 💻 Development Setup

```bash
# Clone
git clone https://github.com/nano-step/ai-sandbox-wrapper.git
cd ai-sandbox-wrapper

# Test setup
./setup.sh

# Run a tool
ai-run claude
```

## 📁 Project Structure

```
├── setup.sh                 # Main setup script
├── lib/
│   ├── install-base.sh      # Base Docker image (Bun + Python)
│   ├── install-{tool}.sh    # Individual tool installers
│   └── generate-ai-run.sh   # Wrapper script generator
├── .github/
│   ├── workflows/           # CI/CD
│   └── ISSUE_TEMPLATE/      # Issue templates
└── README.md
```

## ✅ Code Style

- Use `bash` with `set -e` for scripts
- Follow existing naming conventions
- Add helpful output messages with emoji
- Document security implications

## 📜 License

By contributing, you agree that your contributions will be licensed under the MIT License.
