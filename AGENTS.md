# AI Sandbox Wrapper - Agent Instructions

**Purpose:** Docker-based security sandbox for AI coding agents (Claude, Gemini, Aider, OpenCode, etc.)

## Quick Reference

| Task | Command |
|------|---------|
| Lint all shell scripts | `npm run lint` |
| Lint JavaScript | `npm run lint:js` |
| Run tests | `npm test` |
| Validate single script | `bash -n path/to/script.sh` |
| Build base image | `bash lib/install-base.sh` |
| Build tool image | `bash lib/install-{tool}.sh` |

## Project Structure

```
bin/           # Executables (ai-run, cli.js, setup-ssh-config)
lib/           # Installation scripts (install-{tool}.sh)
dockerfiles/   # Container images (base/, {tool}/)
setup.sh       # Interactive installer
```

## Code Style

### Shell Scripts (95% of codebase)

**Header:**
```bash
#!/usr/bin/env bash
set -e
```

**Variables:**
- Always quote: `"$VAR"` not `$VAR`
- Use `${VAR:-default}` for defaults
- Use `local` in functions: `local my_var="value"`

**Naming:**
- UPPER_CASE for constants/env vars: `SANDBOX_DIR`, `PORT_MAPPINGS`
- lower_case for local vars: `cursor`, `selected`
- snake_case for functions: `migrate_to_sandbox()`, `check_port_in_use()`

**Conditionals:**
```bash
# Use [[ ]] for tests (not [ ])
if [[ -n "$VAR" ]]; then
  # ...
fi

# Use && for simple conditionals
[[ -f "$FILE" ]] && source "$FILE"
```

**Arrays:**
```bash
# Declare arrays
TOOL_ARGS=()
declare -A PORTS_MAP  # Associative array

# Iterate
for item in "${ARRAY[@]}"; do
  # ...
done
```

**Error Handling:**
- `set -e` at top (exit on error)
- Use `|| true` to suppress expected failures
- Warnings: `echo "⚠️  WARNING: message"`
- Errors: `echo "❌ ERROR: message" && exit 1`

**Output Messages:**
```bash
echo "🔄 Migrating..."      # Progress
echo "✅ Done"              # Success
echo "⚠️  WARNING: ..."     # Warning (continue)
echo "❌ ERROR: ..."        # Error (usually exit)
echo "ℹ️  Info message"     # Informational
```

### JavaScript (bin/cli.js)

**Style:**
- Node.js CommonJS (`require`, not `import`)
- 2-space indentation
- Single quotes for strings
- No semicolons (project style)
- camelCase for variables/functions

**Error Handling:**
```javascript
try {
  // ...
} catch (err) {
  const message = err && err.message ? err.message : String(err)
  console.error('❌ Error:', message)
  process.exit(1)
}
```

### Dockerfiles

**Pattern:**
- Base image: `ai-base` (Debian + Bun runtime)
- Non-root user: `agent` (UID 1001)
- Working directory: `/workspace`
- Multi-stage builds when needed

```dockerfile
FROM ai-base:latest
USER agent
WORKDIR /workspace
ENTRYPOINT ["tool-name"]
```

## File Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Tool installer | `lib/install-{tool}.sh` | `lib/install-claude.sh` |
| Dockerfile | `dockerfiles/{tool}/Dockerfile` | `dockerfiles/claude/Dockerfile` |
| Executable | `bin/{command}` | `bin/ai-run` |

## Testing

```bash
# Validate shell syntax (required before commit)
bash -n setup.sh
bash -n lib/*.sh
bash -n bin/ai-run

# Validate JavaScript
node --check bin/cli.js

# Full test suite
npm test

# Test Docker image
docker run --rm ai-{tool}:latest {tool} --version
docker run --rm ai-{tool}:latest {tool} --help
```

## Security Constraints (Non-negotiable)

- ❌ NEVER mount full home directory to containers
- ❌ NEVER share SSH keys by default (opt-in only)
- ❌ NEVER allow network access to host services by default
- ❌ NEVER run containers as root
- ✅ All access requires explicit user consent
- ✅ Containers use CAP_DROP=ALL

## Key Patterns

### Flag Parsing (bin/ai-run)
```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    --flag|-f)
      FLAG_VAR=true
      shift
      ;;
    --flag-with-arg|-a)
      shift
      if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
        ARG_VAR="$1"
        shift
      fi
      ;;
    *)
      REMAINING_ARGS+=("$1")
      shift
      ;;
  esac
done
```

### Interactive Menus (setup.sh)
```bash
tput civis  # Hide cursor
trap 'tput cnorm' INT TERM EXIT  # Restore on exit
# Use tput setaf N for colors (2=green, 6=cyan)
tput sgr0   # Reset colors
```

### Docker Volume Mounts
```bash
VOLUME_MOUNTS="-v $HOST_PATH:$CONTAINER_PATH:delegated"
```

## Common Tasks

### Adding a New Tool

1. Create `lib/install-{tool}.sh`:
```bash
#!/usr/bin/env bash
set -e
# Build logic here
docker build -t ai-{tool}:latest ...
```

2. Create `dockerfiles/{tool}/Dockerfile`
3. Add to `setup.sh` tool selection menu
4. Add to `.gitlab-ci.yml` for CI builds

### Modifying ai-run

1. Add flag parsing in the `while` loop (lines 13-32)
2. Add logic after config setup (~line 1216)
3. Validate: `bash -n bin/ai-run`
4. Test manually before committing

## Git Workflow

- Main branch: `master`
- Development: `beta` (CI triggers here)
- Commit style: Conventional commits (`feat:`, `fix:`, `docs:`)

## Config Locations

| File | Purpose |
|------|---------|
| `~/.ai-sandbox/config.json` | Unified config (workspaces, git, networks) |
| `~/.ai-sandbox/env` | API keys (`KEY=value` format) |
| `~/.ai-sandbox/workspaces` | Legacy workspace list |
| `~/.ai-sandbox/tools/{tool}/home/` | Per-tool sandbox home |


<!-- OPENCODE-MEMORY:START -->
<!-- Managed block - do not edit manually. Updated by: npx nano-brain init -->

## Memory System (nano-brain)

This project uses **nano-brain** for persistent context across sessions.

### Quick Reference

| I want to... | Command |
|--------------|---------|
| Recall past work on a topic | `memory_query("topic")` |
| Find exact error/function name | `memory_search("exact term")` |
| Explore a concept semantically | `memory_vsearch("concept")` |
| Save a decision for future sessions | `memory_write("decision context")` |
| Check index health | `memory_status` |

### Session Workflow

**Start of session:** Check memory for relevant past context before exploring the codebase.
```
memory_query("what have we done regarding {current task topic}")
```

**End of session:** Save key decisions, patterns discovered, and debugging insights.
```
memory_write("## Summary\n- Decision: ...\n- Why: ...\n- Files: ...")
```

### When to Search Memory vs Codebase

- **"Have we done this before?"** → `memory_query` (searches past sessions)
- **"Where is this in the code?"** → grep / ast-grep (searches current files)
- **"How does this concept work here?"** → Both (memory for past context + grep for current code)

<!-- OPENCODE-MEMORY:END -->

