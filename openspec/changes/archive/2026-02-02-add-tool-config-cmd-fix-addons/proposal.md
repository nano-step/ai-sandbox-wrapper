## Why

1.  **Observability**: Users often need to know where their tool configurations (e.g., `claude.json`, `auth.json`) are stored to debug issues or manually edit settings. A built-in command to show this is a major UX improvement.
2.  **Reliability**: Currently, addon tools like `spec-kit` (`specify`) and `ux-ui-promax` (`uipro`) are installed as root during image build, but aren't in the PATH for the `agent` user, making them "missing" in the container.

## What Changes

1.  **Config Inspection Command**: `npx @kokorolx/ai-sandbox-wrapper config <tool>` will:
    -   Display the absolute path on the host to the tool's sandbox home.
    -   Identify and display the path to the primary configuration file if it exists.
    -   Optionally cat the config if a flag is provided (e.g., `--show`).
2.  **Addon Path Fix**:
    -   Modify `lib/install-base.sh` to install `specify-cli` and `uipro-cli` either in `/usr/local/bin` (via symlinks) or ensured to be in the `agent` user's PATH.
    -   Update the `Dockerfile` to include these bin paths in the global `ENV PATH`.

## Capabilities

### New Capabilities
- `tool-config-inspection`: Ability to inspect sandbox configuration for any installed tool.

### Modified Capabilities
- `container-runtime`: Ensure all pre-installed addon tools are correctly registered in the system PATH.

## Impact

- `bin/ai-run`: Addition of `config` sub-command.
- `lib/install-base.sh`: Adjustment of installation steps for spec-kit and ux-ui-promax.
- `dockerfiles/base/Dockerfile`: PATH environment variable updates.
- `README.md`: Document the new `config` command.
