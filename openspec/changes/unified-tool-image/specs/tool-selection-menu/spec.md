## ADDED Requirements

### Requirement: Multi-select tool menu in setup.sh
The `setup.sh` script SHALL present an interactive multi-select menu for choosing which AI tools to include in the unified sandbox image.

#### Scenario: Interactive tool selection
- **WHEN** user runs `setup.sh` interactively
- **THEN** a multi-select checklist SHALL be displayed with all available tools
- **AND** user SHALL be able to toggle tools with SPACE and confirm with ENTER
- **AND** only selected tools SHALL be installed into the unified image

#### Scenario: Pre-selecting previously installed tools
- **WHEN** user runs `setup.sh` and `~/.ai-sandbox/config.json` contains `tools.installed`
- **THEN** the menu SHALL pre-select (check) the previously installed tools
- **AND** user SHALL be able to add or remove tools from the selection

#### Scenario: No tools selected
- **WHEN** user confirms the menu with zero tools selected
- **THEN** setup SHALL display "No tools selected for installation"
- **AND** setup SHALL exit without building an image

### Requirement: Setup builds unified image
After tool selection, `setup.sh` SHALL invoke the unified build script instead of individual per-tool install scripts.

#### Scenario: Setup with tool selection
- **WHEN** user selects "claude" and "opencode" from the tool menu
- **AND** selects "rtk" and "playwright-mcp" from enhancement menus
- **THEN** `setup.sh` SHALL call `build-sandbox.sh` once with all selections
- **AND** one `ai-sandbox:latest` image SHALL be built
- **AND** no per-tool images (`ai-claude:latest`, `ai-opencode:latest`) SHALL be built

#### Scenario: Setup generates shell aliases
- **WHEN** setup completes with tools "claude" and "opencode"
- **THEN** shell aliases SHALL be added: `alias claude="ai-run claude"` and `alias opencode="ai-run opencode"`
- **AND** an alias `alias ai="ai-run"` SHALL be added for shell-first access

### Requirement: Old image cleanup
`setup.sh` SHALL detect and offer to remove orphaned per-tool images from previous installations.

#### Scenario: Old per-tool images detected
- **WHEN** `setup.sh` runs and finds existing `ai-claude:latest`, `ai-opencode:latest` images
- **THEN** it SHALL prompt: "Found old per-tool images. Remove them to free disk space?"
- **AND** if user confirms, it SHALL run `docker rmi` on the old images

#### Scenario: No old images found
- **WHEN** `setup.sh` runs and no `ai-{tool}:latest` images exist (fresh install)
- **THEN** no cleanup prompt SHALL be shown
