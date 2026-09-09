## ADDED Requirements

### Requirement: Pyright LSP available
The base and sandbox container images SHALL include `pyright` as a globally installed npm package.

#### Scenario: Pyright provides Python diagnostics
- **WHEN** OpenCode is configured with pyright as the Python LSP
- **THEN** the `pyright` binary SHALL be available in the system PATH
- **AND** OpenCode's `diagnostics` tool SHALL return type errors for Python files

### Requirement: HTML/CSS/JSON LSP available
The base and sandbox container images SHALL include `vscode-langservers-extracted` as a globally installed npm package.

#### Scenario: Web language servers are accessible
- **WHEN** a container is started from the base or sandbox image
- **THEN** `vscode-html-language-server`, `vscode-css-language-server`, and `vscode-json-language-server` SHALL be available in the system PATH
