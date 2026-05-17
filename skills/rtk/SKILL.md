---
name: rtk
description: "Token optimizer for AI coding agents. Wraps common CLI commands with rtk to reduce LLM token consumption by 60-90%."
compatibility: "OpenCode with RTK binary installed"
metadata:
  author: Sisyphus
  version: "1.0.0"
---

# RTK — Rust Token Killer

**Purpose**: Reduce token consumption by 60-90% on shell commands. RTK filters and compresses command output before it reaches your context.

## When This Skill Activates

This skill is loaded automatically. Once active, **always** prefix supported commands with `rtk`.

## Command Mappings (MANDATORY)

When running shell commands via Bash tool, use `rtk` prefix for these commands:

| Instead of | Use | Savings |
|-----------|-----|---------|
| `git status` | `rtk git status` | ~80% |
| `git diff` | `rtk git diff` | ~75% |
| `git log` | `rtk git log` | ~80% |
| `git add/commit/push/pull` | `rtk git add/commit/push/pull` | ~90% |
| `ls` / `ls -la` | `rtk ls` | ~80% |
| `cat file` | `rtk read file` | ~70% |
| `grep pattern .` | `rtk grep pattern .` | ~80% |
| `rg pattern` | `rtk grep pattern .` | ~80% |
| `npm test` / `cargo test` / `pytest` | `rtk test <cmd>` | ~90% |
| `npm run build` / `cargo build` | `rtk err <cmd>` | ~80% |
| `gh pr list/view` | `rtk gh pr list/view` | ~70% |
| `docker ps` | `rtk docker ps` | ~80% |
| `eslint` / `tsc` | `rtk lint` / `rtk tsc` | ~80% |

## Searching Inside `node_modules` / Ignored Directories

By default, `rtk grep` respects `.gitignore` rules — meaning `node_modules`, `.nuxt`, `dist`, etc. are **excluded**. This is the right behavior 99% of the time.

When you **need** to search inside ignored directories (debugging a library, checking an API signature, tracing a dependency bug):

```bash
# Search all files including node_modules (--no-ignore bypasses .gitignore)
rtk grep "defineStore" . --no-ignore

# Search a specific package only (combine --no-ignore with --glob)
rtk grep "defineStore" . --no-ignore --glob 'node_modules/pinia/**'
```

**What does NOT work:**
- `rtk grep "pattern" node_modules/pinia/` — still excluded even with direct path
- `rtk grep "pattern" . --glob 'node_modules/**'` — glob alone doesn't override .gitignore

**Key flag: `--no-ignore`** — this is the ONLY way to search ignored directories with rtk grep.

### Other useful `rtk grep` flags

```bash
rtk grep "pattern" . -t ts          # Filter by file type (ts, py, rust, etc.)
rtk grep "pattern" . -m 100         # Increase max results (default: 50)
rtk grep "pattern" . -u             # Ultra-compact mode (even fewer tokens)
rtk grep "pattern" . -l 120         # Max line length before truncation (default: 80)
```

## Commands to NOT Wrap

Do NOT prefix these with `rtk` (unsupported or counterproductive):

- `npx`, `npm install`, `pip install` (package managers)
- `node`, `python3`, `ruby` (interpreters)
- `nano-brain`, `openspec`, `opencode` (custom tools)
- Heredocs (`<<EOF`)
- Piped commands (`cmd1 | cmd2`) — wrap only the first command if applicable
- Commands already prefixed with `rtk`

## How RTK Works

```
Without RTK:  git status → 50 lines raw output → 2,000 tokens
With RTK:     rtk git status → "3 modified, 1 untracked ✓" → 200 tokens
```

RTK runs the real command, then filters/compresses the output. The agent sees a compact summary instead of verbose raw output.

## Detection

Before using RTK commands, verify it's installed:
```bash
rtk --version
```

If `rtk` is not found, skip this skill — run commands normally without the `rtk` prefix.

## Token Savings Reference

Typical 30-min coding session:
- Without RTK: ~150,000 tokens
- With RTK: ~45,000 tokens
- **Savings: ~70%**

Biggest wins: test output (`rtk test` — 90%), git operations (`rtk git` — 80%), file reading (`rtk read` — 70%).
