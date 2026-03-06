# claude-ccs-integration Specification

## Purpose
CCS (Claude Code Switch) installation and configuration for multi-provider model switching and multi-account management inside the Docker sandbox.

## ADDED Requirements

### Requirement: CCS Installation
The Claude Code Docker image SHALL include CCS installed globally via npm.

#### Scenario: CCS available in container
- **WHEN** user runs `ai-run claude --shell`
- **AND** types `ccs --version` inside the container
- **THEN** CCS SHALL be installed and display its version
- **AND** CCS SHALL be executable by the non-root `agent` user

#### Scenario: CCS binary accessible
- **WHEN** CCS is installed via `npm install -g @kaitranntt/ccs`
- **THEN** the `ccs` binary SHALL be available in the system PATH
- **AND** running `ccs help` SHALL display available commands

### Requirement: CCS Configuration Persistence
CCS configuration SHALL persist across container restarts via a dedicated volume mount.

#### Scenario: CCS config directory mounted
- **WHEN** user runs `ai-run claude`
- **THEN** the host directory `~/.ccs` SHALL be mounted to `/home/agent/.ccs` in the container
- **AND** the mount SHALL use the `mount_tool_config` function pattern

#### Scenario: CCS config persistence
- **WHEN** user configures CCS providers inside the container (e.g., `ccs config add openrouter`)
- **AND** the container is stopped and restarted
- **THEN** CCS configuration at `~/.ccs/config.yaml` SHALL be preserved
- **AND** provider profiles SHALL be available in the new container session

#### Scenario: CCS OAuth token persistence
- **WHEN** user authenticates with an OAuth provider (e.g., Gemini)
- **AND** the container is stopped and restarted
- **THEN** OAuth tokens at `~/.ccs/cliproxy/auth/` SHALL be preserved
- **AND** re-authentication SHALL not be required

### Requirement: CCS Provider API Keys
The sandbox SHALL support passing provider API keys to CCS via the env file.

#### Scenario: OpenRouter API key
- **WHEN** user adds `OPENROUTER_API_KEY=sk-or-...` to `~/.ai-sandbox/env`
- **AND** runs `ai-run claude`
- **THEN** the API key SHALL be available inside the container
- **AND** CCS SHALL be able to use OpenRouter as a provider

#### Scenario: Multiple provider keys
- **WHEN** user adds multiple provider keys to `~/.ai-sandbox/env` (OPENROUTER_API_KEY, GOOGLE_API_KEY, etc.)
- **THEN** all keys SHALL be passed to the container via `--env-file`
- **AND** CCS SHALL be able to switch between configured providers

### Requirement: OAuth Provider Limitations
OAuth-based CCS providers SHALL be documented as having limitations in headless Docker containers.

#### Scenario: OAuth provider in headless container
- **WHEN** user attempts to use an OAuth provider (Gemini, Copilot, Codex) in the container
- **THEN** the provider MAY fail if browser-redirect OAuth is required
- **AND** documentation SHALL recommend API-key providers for container use

#### Scenario: Device flow OAuth
- **WHEN** user attempts to use a device-flow OAuth provider (e.g., Copilot)
- **THEN** the device flow MAY work via URL copy-paste from terminal output
- **AND** this behavior SHALL be documented as "may work" rather than guaranteed
