## Why

Entering folder paths during setup is a high-friction task for new users ("newbies"). It requires knowing absolute paths and thinking about security whitelisting before even trying the tools. We want to defer this decision to when it's actually relevant—when a tool is first run in a project directory.

## What Changes

1.  **Setup Simplification**: `setup.sh` will no longer require workspace paths. It will allow leaving the input empty and will default to whitelisting the current directory if the user chooses.
2.  **Just-In-Time Whitelisting**: `ai-run` will detect if it's being run outside a whitelisted workspace and provide a user-friendly prompt to "allow this path".
3.  **Config Resilience**: Ensure `ai-run` can initialize the base configuration file if it's missing or empty, preventing "Workspaces not configured" errors.

## Capabilities

### New Capabilities
- `on-demand-whitelisting`: Automatically prompt and whitelist the current directory when running tools in non-whitelisted paths.

### Modified Capabilities
- `setup-workspaces`: Make workspace configuration optional during the initial installation process.

## Impact

- `setup.sh`: Modified to allow empty input and handle defaults.
- `bin/ai-run`: Modified security check logic to be interactive and handle config initialization.
- `~/.ai-sandbox/config.json`: Structure is preserved, but will be managed more dynamically.
