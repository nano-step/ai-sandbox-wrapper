## ADDED Requirements

### Requirement: Ripgrep File Search Support
The base image SHALL include the ripgrep (`rg`) binary to provide fast file search capabilities for AI tools that depend on it.

#### Scenario: Ripgrep binary available in container
- **WHEN** a container is started from an image built on ai-base
- **THEN** the `rg` command SHALL be available in PATH
- **AND** running `rg --version` SHALL succeed and display version information

#### Scenario: Ripgrep executes file search
- **WHEN** ripgrep is invoked with a search pattern and directory
- **THEN** it SHALL search files recursively and return matching results
- **AND** the search SHALL work regardless of host platform architecture

#### Scenario: OpenCode file search works in sandbox
- **WHEN** OpenCode's "@" file reference feature is used inside the container
- **THEN** file search SHALL succeed using the system ripgrep binary
- **AND** users SHALL be able to search and reference files by name or pattern

#### Scenario: Architecture-independent operation
- **WHEN** the container runs on Linux ARM64 (aarch64)
- **AND** the host mounts a macOS Mach-O ripgrep binary at `~/.local/share/opencode/bin/rg`
- **THEN** the system ripgrep at `/usr/bin/rg` SHALL be used instead
- **AND** no "Exec format error" SHALL occur during file search operations
