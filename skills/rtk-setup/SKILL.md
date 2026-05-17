---
name: rtk-setup
description: "One-time setup + ongoing enforcement of RTK (Rust Token Killer) across sessions and subagents. Persists RTK instructions to AGENTS.md and propagates to delegated tasks."
compatibility: "OpenCode with RTK binary installed"
metadata:
  author: Sisyphus
  version: "1.0.0"
---

# RTK Setup — Persistent RTK Enforcement

This skill performs **setup** (persist RTK instructions) and **ongoing enforcement** (use rtk, propagate to subagents).

## Phase 1: Detection (ALWAYS run first)

Run these checks before anything else:

```bash
rtk --version
```

- If `rtk` is NOT found → **STOP**. Tell the user: "RTK is not installed. Install it first: `cargo install --git https://github.com/rtk-ai/rtk --locked`". Do NOT proceed with setup.
- If `rtk` IS found → continue.

### Check oh-my-opencode

```bash
ls ~/.config/opencode/oh-my-opencode.json 2>/dev/null
```

- If found → omo is installed. Note this for Phase 2.
- If not found → skip omo-specific steps.

## Phase 2: Setup (persist to AGENTS.md)

Check BOTH of these files for the RTK managed block:

1. **User-level**: `~/.config/opencode/AGENTS.md`
2. **Project-level**: `./AGENTS.md` (current workspace)

For EACH file, check if `<!-- RTK:START -->` exists. If it does NOT exist, **append** the following managed block to the file (create the file if it doesn't exist). NEVER replace existing content — only append.

```markdown
<!-- RTK:START -->
<!-- Managed block - do not edit manually. Updated by: rtk-setup skill -->

## RTK Token Optimizer

This project uses **RTK** (Rust Token Killer) to reduce LLM token consumption by 60-90%.

### Rules for ALL agents (including subagents)

**ALWAYS** prefix these commands with `rtk`:

| Command | Use instead |
|---------|-------------|
| `git status/diff/log/add/commit/push/pull` | `rtk git ...` |
| `ls`, `ls -la` | `rtk ls` |
| `cat file` | `rtk read file` |
| `grep pattern .` / `rg pattern` | `rtk grep pattern .` |
| `npm test` / `cargo test` / `pytest` | `rtk test <cmd>` |
| `npm run build` / `cargo build` | `rtk err <cmd>` |
| `gh pr list/view` | `rtk gh pr list/view` |
| `docker ps` | `rtk docker ps` |
| `eslint` / `tsc` | `rtk lint` / `rtk tsc` |

**Do NOT** prefix: `npx`, `npm install`, `pip install`, `node`, `python3`, heredocs, piped commands.

<!-- RTK:END -->
```

### If oh-my-opencode is installed

After updating AGENTS.md files, check if the omo config at `~/.config/opencode/oh-my-opencode.json` has `prompt_append` fields on agents. If it does, inform the user:

> "omo is installed. For maximum coverage, you can add RTK instructions to agent `prompt_append` fields in `oh-my-opencode.json`. This ensures subagents always use rtk even when AGENTS.md is not loaded. Want me to do this?"

**Only modify `oh-my-opencode.json` if the user explicitly confirms.** If they confirm, append this line to the `prompt_append` of `sisyphus-junior` agent (the primary coder):

```
\n\nRTK: ALWAYS prefix shell commands with `rtk` when available (git, ls, grep, test, build). Example: `rtk git status` not `git status`.
```

Do NOT modify other agents' prompt_append unless asked.

## Phase 3: Ongoing Enforcement (EVERY time this skill is loaded)

### For the current agent

From this point forward in this session, **you MUST**:

1. **Use `rtk` prefix** for all supported shell commands (see table above)
2. **Verify rtk is available** before first use: `rtk --version`
3. If rtk is not available in the current environment, fall back to normal commands silently

### For subagent delegation

When delegating ANY task that involves shell commands (via `task()`, `delegate_task()`, or any delegation mechanism), **ALWAYS** add this to the `MUST DO` section of the delegation prompt:

```
- Use `rtk` prefix for shell commands when available (git, ls, grep, test, build). Run `rtk --version` first to check. If not installed, use normal commands. Examples: `rtk git status`, `rtk ls`, `rtk grep pattern .`, `rtk test npm test`.
```

This is NON-NEGOTIABLE. Subagents do not read AGENTS.md, so RTK instructions MUST be passed explicitly in every delegation prompt.

### Quick reference for subagent prompts

Copy-paste this one-liner into MUST DO sections:

> Use `rtk` prefix for all shell commands (git, ls, grep, test, build, docker). Example: `rtk git status` not `git status`. If `rtk` is not found, use normal commands.

## Summary

| Phase | When | What |
|-------|------|------|
| Detection | Always first | Check rtk installed, check omo |
| Setup | Once (idempotent) | Append RTK block to AGENTS.md (user + project) |
| Enforcement | Every session | Use rtk yourself, propagate to all subagents |
