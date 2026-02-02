## Context

Currently, the AI Sandbox requires at least one whitelisted workspace directory to be provided during `setup.sh`. If not provided, the script fails. In `ai-run`, if no workspaces are found in the configuration, it aborts with an error suggesting to run `setup.sh`. This is a hurdle for new users who just want to try the tools.

## Goals / Non-Goals

**Goals:**
- Allow `setup.sh` to complete without manual workspace input.
- Enable `ai-run` to handle the whitelisting process interactively during first use.
- Ensure the configuration system is resilient to missing or empty workspace lists.

**Non-Goals:**
- Removing the security whitelisting feature entirely.
- Changing the underlying Docker volume mount mechanism.

## Decisions

### 1. Relax `setup.sh` Requirement
`setup.sh` will no longer exit if `WORKSPACES` is empty. It will simply proceed to tool installation. This allows users to "Skip" the workspace configuration and handle it later.

### 2. Interactive Whitelisting in `ai-run`
`ai-run` already has an interactive whitelisting prompt, but it's currently unreachable if no workspaces were configured during setup.
- Remove the "Workspaces not configured" fatal error in `ai-run`.
- Ensure `init_config` is called early so that `add_workspace` can persist the user's choice even on the first run.

### 3. Config Resilience
- `read_workspaces` will handle empty results gracefully.
- The whitelisting check will trigger if the current directory is not in the (possibly empty) list of allowed paths.

## Risks / Trade-offs

- **Risk**: Users might accidentally whitelist sensitive folders if they just hit "Y" without thinking.
- **Mitigation**: The prompt includes a clear security warning.
- **Trade-off**: Deferring whitelisting adds one interactive step to the first run of a tool, but makes the overall installation feel much faster and simpler.
