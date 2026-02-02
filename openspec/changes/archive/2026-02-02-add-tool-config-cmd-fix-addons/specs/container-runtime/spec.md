## ADDED Requirements

### Requirement: core-addons-availability
Standard addon tools (`uipro`, `specify`) MUST be available and executable by the non-root `agent` user within the AI sandbox container environment.

#### Scenario: run-uipro-in-container
- **WHEN** user executes `ai-run <tool> --shell`
- **AND** types `uipro --version` inside the container
- **THEN** command should execute successfully and show the version

#### Scenario: run-specify-in-container
- **WHEN** user executes `ai-run <tool> --shell`
- **AND** types `specify --help` inside the container
- **THEN** command should execute successfully and show help output

### Requirement: global-addon-path
Addon binaries MUST be installed into a directory that is included in the global system `PATH` of the container image.

#### Scenario: verify-path-for-addons
- **WHEN** building the base image with `INSTALL_SPEC_KIT=1` and `INSTALL_UX_UI_PROMAX=1`
- **THEN** binaries should be located in `/usr/local/bin` or verified in `$PATH`.
