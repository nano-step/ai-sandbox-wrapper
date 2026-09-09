## Context

Currently, the `ai-run` command only serves as a runner. Users don't have a clear way to see where configurations are stored without digging into the script. Additionally, addons like `spec-kit` and `ux-ui-promax` are installed during image build but aren't easily accessible to the `agent` user due to inconsistent bin paths.

## Goals / Non-Goals

**Goals:**
- Provide a `config` subcommand for `ai-run`.
- Fix the visibility/accessibility of container addons.
- Maintain security and isolation.

**Non-Goals:**
- Creating a full configuration manager (only inspection for now).
- Modifying the tool configuration logic itself.

## Decisions

### 1. `npx @kokorolx/ai-sandbox-wrapper config tool <tool>` Implementation
- **Rationale**: The `bin/cli.js` (entry point for npx) is better suited for administrative tasks and configuration inspection than the `ai-run` runner script.
- **Logic**:
  - Add a `config tool <tool>` subcommand to `bin/cli.js`.
  - Reuse `SANDBOX_DIR` and `CONFIG_PATH` constants in `bin/cli.js`.
  - Add a helper to map tool names to their typical config filenames (e.g., `claude` -> `.claude.json`).
  - Search current directory and sandbox tool home for the config file.
- **Alternatives**:
  - *Add to ai-run*: User preferred npx for this administrative task.

### 2. Addon Installation Fix
- **Decision**: Install `specify-cli` and `uipro-cli` into `/usr/local/bin` using appropriate flags or symlinks.
- **Rationale**: `/usr/local/bin` is in the default PATH for all users (including `agent`).
- **Implementation**:
  - `pipx install --global specify-cli`: Note that `pipx` doesn't have a simple `--global` that works for all users easily. We will symlink the bin: `ln -s /root/.local/bin/specify /usr/local/bin/specify`.
  - `bun install -g`: We will set `BUN_INSTALL=/usr/local` or symlink the output.
- **Alternatives**:
  - *Modify agent user PATH*: Requires updating `.bashrc` or `ENV` in Dockerfile. Simple but might miss some shells. Global symlinks are more robust.

## Risks / Trade-offs

- **[Risk] Path Conflicts** → Mitigation: Ensure symlinks only for verified tools.
- **[Risk] Config Detection Fragility** → Mitigation: Only support the most common config files for each tool initially.
