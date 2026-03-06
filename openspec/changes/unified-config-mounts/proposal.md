## Why

The unified tool image (`ai-sandbox:latest`) puts all selected tools in one container. But `ai-run` still mounts configs as if each tool runs in isolation:

1. **Config mounts are tool-gated**: `ai-run opencode` only mounts `~/.config/opencode`. If the user runs `amp` or `claude` inside the same container, those tools write config to the sandbox home dir (`~/.ai-sandbox/tools/opencode/home/.config/amp/`) instead of the real host config (`~/.config/amp/`). The config is stranded — invisible to future `ai-run amp` sessions.

2. **Home dir is per-tool**: `ai-run opencode` uses `~/.ai-sandbox/tools/opencode/home/`, `ai-run claude` uses `~/.ai-sandbox/tools/claude/home/`, shell mode uses `~/.ai-sandbox/tools/shell/home/`. With the unified image, a user may switch tools mid-session or use shell mode to run any tool. Per-tool home dirs fragment state — shell history, dotfiles, and tool-generated files are scattered across N directories.

3. **Shell mode gets zero configs**: `ai-run` without a tool argument sets `$TOOL=""`, so the entire config mount block is skipped. The user enters a container with all tools installed but none configured.

## What Changes

- **Mount ALL installed tools' configs**: Instead of gating config mounts on `$TOOL`, read `config.json` `tools.installed` array and mount every installed tool's config directories. This ensures any tool run inside the container sees its real host config.
- **Single shared home directory**: Replace per-tool `~/.ai-sandbox/tools/{tool}/home/` with a single `~/.ai-sandbox/home/` mounted as `/home/agent` for all sessions. Shell history, dotfiles, and tool state are shared.
- **Shell mode gets full config**: With the above changes, shell mode automatically gets all configs and the shared home — no special handling needed.
- **Migrate existing per-tool home dirs**: On first run, detect existing `~/.ai-sandbox/tools/*/home/` directories and merge them into `~/.ai-sandbox/home/`. Warn on conflicts.

## Capabilities

### New Capabilities
- `unified-config-mounts`: Mount all installed tools' config directories into every container session, regardless of which tool is specified on the command line.

### Modified Capabilities
- `container-runtime`: Home directory changes from per-tool (`tools/{tool}/home/`) to shared (`home/`). Config mount logic changes from tool-gated case statement to loop over installed tools.

## Impact

- **`bin/ai-run`**: Config mount block (~70 lines) rewritten. `HOME_DIR` logic simplified. Migration function added.
- **`bin/cli.js`**: `config tool` command may need path updates for the new home dir location.
- **Existing users**: Per-tool home dirs are migrated automatically. First run after update triggers migration with user-visible output.
- **Security**: No change — same bind-mount approach, same host paths, same permissions. Config dirs are user-owned and contain only tool settings.
- **Cross-platform**: No new concerns — bind mounts work identically on macOS, Linux, WSL2.
