# tool-config-inspection Specification

## Purpose
The tool-config-inspection capability allows users to discover and inspect the configuration files and persistent home directories for individual tools managed by the AI Sandbox.

## Requirements

### Requirement: show-tool-home-path
The `npx @kokorolx/ai-sandbox-wrapper config tool <tool>` command MUST display the absolute path to the tool's persistent home directory on the host machine.

#### Scenario: inspect-claude-config
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper config tool claude`
- **THEN** output should include "Host Home: $HOME/.ai-sandbox/tools/claude/home"

### Requirement: show-primary-config-file
The `npx @kokorolx/ai-sandbox-wrapper config tool <tool>` command SHALL identify and display the path to the primary configuration file if it exists.

#### Scenario: show-claude-json-path
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper config tool claude`
- **AND** `.claude.json` exists in host current directory or sandbox home
- **THEN** output should show the path to that specific JSON file.

### Requirement: cat-tool-config
The `npx @kokorolx/ai-sandbox-wrapper config tool <tool> --show` flag SHALL output the content of the primary configuration file.

#### Scenario: cat-claude-config
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper config tool claude --show`
- **THEN** display the content of the detected `.claude.json` file.
