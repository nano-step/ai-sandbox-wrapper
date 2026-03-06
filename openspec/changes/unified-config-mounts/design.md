## Context

`ai-run` currently uses a per-tool home directory and tool-gated config mounts. The unified image change (`unified-tool-image`) put all tools in one container but didn't update the config/home architecture. This creates config fragmentation when users switch tools inside a unified container.

The config mount system has two parts:
1. **Home dir mount**: `~/.ai-sandbox/tools/{tool}/home/` → `/home/agent` (base layer for dotfiles, shell history, etc.)
2. **Config overlay mounts**: `~/.config/{tool}` → `/home/agent/.config/{tool}` (bind-mounted on top of home, so tool configs persist to the real host location)

The overlay approach is correct — the problem is that only one tool's overlays are applied per session.

## Goals / Non-Goals

**Goals:**
- All installed tools' configs are bind-mounted into every container session
- Single shared home directory for all sessions (shell mode, tool mode, any tool)
- Existing per-tool home dirs are migrated automatically
- Zero user configuration needed — works after update

**Non-Goals:**
- Changing which config paths each tool uses (those are tool-defined, not ours)
- Supporting per-tool home isolation as an option (unified image = unified home)
- Changing the shared cache mounts (handled by `shared-package-cache` change)

## Decisions

### 1. Config mount registry

**Decision**: Define a config mount registry as an associative array in `ai-run`, mapping tool names to their config paths. Loop over `config.json` `tools.installed` and mount all matching configs.

```bash
declare -A TOOL_CONFIGS
TOOL_CONFIGS=(
  ["amp"]=".config/amp .local/share/amp"
  ["opencode"]=".config/opencode .local/share/opencode"
  ["claude"]=".claude .ccs"
  ["openclaw"]=".openclaw"
  ["droid"]=".config/droid"
  ["qoder"]=".config/qoder"
  ["auggie"]=".config/auggie"
  ["codebuddy"]=".config/codebuddy"
  ["jules"]=".config/jules"
  ["shai"]=".config/shai"
  ["gemini"]=".config/gemini"
  ["aider"]=".config/aider .aider"
  ["kilo"]=".config/kilo"
  ["codex"]=".config/codex"
  ["qwen"]=".config/qwen"
)
```

Then:
```bash
for tool in $(get_installed_tools); do
  for cfg_path in ${TOOL_CONFIGS[$tool]}; do
    mount_tool_config "$HOME/$cfg_path" "$cfg_path"
  done
done
```

**Why not keep the case statement?** The case statement requires knowing which tool is active. With unified image, we need all tools' configs regardless of `$TOOL`. A registry + loop is cleaner and easier to extend when adding new tools.

**Special handling**: OpenCode's bundled skills copy logic stays as a separate block — it's not a mount, it's a file copy that runs on the host before container launch.

### 2. Shared home directory

**Decision**: Replace `~/.ai-sandbox/tools/{tool}/home/` with `~/.ai-sandbox/home/`.

```bash
HOME_DIR="$SANDBOX_DIR/home"
```

No more per-tool branching. Shell mode, `ai-run opencode`, `ai-run claude` — all use the same home.

**Why not keep per-tool homes?** With the unified image, the user expects to switch tools freely inside one container. Per-tool homes mean shell history, `.bashrc` customizations, and tool-generated files are invisible across sessions. A shared home matches the mental model of "one sandbox, all my tools."

### 3. Migration strategy

**Decision**: On first run after update, detect existing per-tool home dirs and merge into `~/.ai-sandbox/home/`.

```bash
if [[ ! -f "$SANDBOX_DIR/.migrated-unified-home" ]]; then
  # For each tools/*/home/, rsync into home/ (skip conflicts)
  for tool_home in "$SANDBOX_DIR"/tools/*/home; do
    [[ -d "$tool_home" ]] || continue
    rsync -a --ignore-existing "$tool_home/" "$SANDBOX_DIR/home/"
  done
  touch "$SANDBOX_DIR/.migrated-unified-home"
fi
```

**Why `--ignore-existing`?** If two tools wrote different `.bashrc` files, keep the first one found. The user can manually reconcile. This is safe — no data is deleted, old dirs remain until the user cleans up.

### 4. Installed tools discovery

**Decision**: Read `config.json` `tools.installed` array via `jq`. Fall back to mounting all known configs if `jq` is unavailable or `tools.installed` is empty.

```bash
get_installed_tools() {
  if command -v jq &>/dev/null && [[ -f "$AI_SANDBOX_CONFIG" ]]; then
    jq -r '.tools.installed[]? // empty' "$AI_SANDBOX_CONFIG" 2>/dev/null
  fi
}
```

If no installed tools are found, fall back to mounting configs for all tools in the registry — better to mount too many (empty dirs are harmless) than too few.

## Risks / Trade-offs

**[Shared home may have conflicting dotfiles]** → Low risk. Most tools write to `.config/{tool}/` (namespaced). The only shared files are `.bashrc`, `.profile`, shell history. Migration uses `--ignore-existing` to avoid overwrites.

**[Per-tool home dirs become orphaned]** → Acceptable. Old dirs remain at `~/.ai-sandbox/tools/*/home/` until the user runs `clean`. No data loss. Add a note in the migration output suggesting cleanup.

**[Mounting many config dirs adds docker run args]** → Negligible. Each mount adds ~60 chars to the command. 15 tools × 2 paths = 30 mounts ≈ 1.8KB of args. Well within Docker's limits.

**[Breaking change for users who rely on per-tool isolation]** → This is intentional. The unified image is a new paradigm — per-tool isolation doesn't make sense when all tools share one container. Users who want isolation should use per-tool images (legacy mode).
