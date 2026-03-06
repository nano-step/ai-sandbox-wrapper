# container-runtime Specification (Delta)

## MODIFIED Requirements

### Requirement: Claude Tool Configuration Mounts
The container runtime SHALL mount CCS configuration directory for Claude Code containers.

#### Scenario: CCS config mount for Claude
- **WHEN** user runs `ai-run claude`
- **THEN** the host directory `~/.ccs` SHALL be mounted to `/home/agent/.ccs` in the container
- **AND** the mount SHALL follow the existing `mount_tool_config` pattern
- **AND** the directory SHALL be created on the host if it does not exist

#### Scenario: CCS mount does not affect other tools
- **WHEN** user runs `ai-run opencode` or any non-Claude tool
- **THEN** no CCS-related mounts SHALL be added
- **AND** the container configuration SHALL remain unchanged
