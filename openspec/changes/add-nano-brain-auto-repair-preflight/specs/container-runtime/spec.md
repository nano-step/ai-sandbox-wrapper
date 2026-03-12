## ADDED Requirements

### Requirement: Nano-brain preflight dependency check
The container runtime (`bin/ai-run`) SHALL perform a nano-brain dependency preflight before executing nano-brain commands, unless explicitly disabled.

#### Scenario: Preflight runs for nano-brain command
- **WHEN** user runs a nano-brain command via `ai-run`
- **AND** auto-repair is not disabled
- **THEN** runtime SHALL execute a preflight check for known nano-brain runtime dependencies
- **AND** runtime SHALL continue to nano-brain execution if checks pass

#### Scenario: Preflight skipped for non-nano-brain tools
- **WHEN** user runs `ai-run` with a tool other than nano-brain
- **THEN** runtime SHALL NOT execute nano-brain preflight logic

### Requirement: Known native-binding failure auto-repair
The container runtime SHALL detect known nano-brain native-binding failures (including tree-sitter binding issues) and attempt automatic repair steps.

#### Scenario: Missing native binding detected
- **WHEN** nano-brain startup output contains known missing native-binding signatures
- **THEN** runtime SHALL run supported repair commands
- **AND** runtime SHALL re-attempt nano-brain execution once after successful repair

#### Scenario: Architecture mismatch binding detected
- **WHEN** nano-brain startup output indicates architecture mismatch for native modules
- **THEN** runtime SHALL run supported cleanup/reinstall steps for affected dependencies
- **AND** runtime SHALL show repair status and retry outcome

### Requirement: Auto-repair transparency and opt-out
The container runtime SHALL provide explicit logs for preflight and repair actions and support opt-out control.

#### Scenario: Repair logs are visible
- **WHEN** runtime performs preflight or auto-repair
- **THEN** user SHALL see messages indicating detected issue, action taken, and result

#### Scenario: Auto-repair disabled
- **WHEN** user sets the documented opt-out flag or environment variable
- **THEN** runtime SHALL skip automatic repair behavior
- **AND** runtime SHALL display actionable manual repair guidance on failure