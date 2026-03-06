## Decisions

## 2026-03-06 Design Decisions (from design.md)
- Config registry: associative array `TOOL_CONFIGS` mapping tool name → space-separated config paths
- `get_installed_tools()` reads config.json via jq, falls back to all known tools
- Shared home: `HOME_DIR="$SANDBOX_DIR/home"` unconditionally (no per-tool branching)
- Migration: rsync --ignore-existing from tools/*/home/ into home/, marker file `.migrated-unified-home`
- OpenCode skills copy stays as separate block, gated on "opencode in installed tools" not "$TOOL == opencode"
