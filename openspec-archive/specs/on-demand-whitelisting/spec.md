# Capability: on-demand-whitelisting

## Requirements

### Requirement: auto-whitelist-prompt
When an AI tool is run outside a whitelisted workspace, the user should be prompted to whitelist the current directory instead of being blocked with an error.

#### Scenario: run-in-unwhitelisted-folder
- **WHEN** user runs `ai-run <tool>` or an alias in a folder not in `config.json`
- **THEN** show a prompt: "Do you want to whitelist the current directory? [y/N]"
- **AND** if "y", add current directory to `config.json` and proceed with execution
- **AND** if "n", abort with security warning

### Requirement: config-initialization
If `config.json` is missing or invalid, `ai-run` should initialize it with default values instead of failing.

#### Scenario: missing-config
- **WHEN** `ai-run` is executed and `~/.ai-sandbox/config.json` does not exist
- **THEN** initialize a default v2 config and proceed to whitelisting check
