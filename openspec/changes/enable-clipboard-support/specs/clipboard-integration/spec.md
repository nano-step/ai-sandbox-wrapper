## ADDED Requirements

### Requirement: Bi-directional text clipboard
The system MUST allow text copied on the host to be accessible inside the container via standard clipboard tools, and MUST allow text copied inside the container to be available on the host clipboard.

#### Scenario: Host-to-container clipboard access
- **WHEN** the host clipboard contains text and the container has display forwarding enabled
- **THEN** clipboard tools inside the container (e.g., `xclip`, `wl-paste`) can read the host clipboard content

#### Scenario: Container-to-host clipboard access
- **WHEN** text is copied from within the container using clipboard tools
- **THEN** the host clipboard reflects the copied text

### Requirement: Automatic display configuration
The `ai-run` wrapper MUST automatically detect the host's display server (X11 or Wayland) and configure the container environment accordingly without user intervention for standard setups.

#### Scenario: X11 host detected
- **WHEN** `DISPLAY` is set on the host
- **THEN** the container starts with X11 environment variables and socket mounts configured for clipboard tools

#### Scenario: Wayland host detected
- **WHEN** `WAYLAND_DISPLAY` is set on the host
- **THEN** the container starts with Wayland environment variables and socket mounts configured for clipboard tools

### Requirement: Platform support
The solution MUST work on Linux hosts with X11 or Wayland and MUST handle macOS environments where X11/XQuartz is available to support clipboard-aware tools. The solution MUST ensure container startup continues even if macOS clipboard integration cannot be enabled.

#### Scenario: Linux host
- **WHEN** the host is Linux with X11 or Wayland available
- **THEN** the container supports clipboard operations using the forwarded display server

#### Scenario: macOS host with X11
- **WHEN** the host is macOS with XQuartz and X11 available
- **THEN** the container can use X11 forwarding for clipboard tools when a display is detected

#### Scenario: macOS host without X11
- **WHEN** the host is macOS without X11 available
- **THEN** the container starts without clipboard integration and reports no failure

### Requirement: Graceful degradation
If no display server is found, the container MUST start successfully without clipboard support.

#### Scenario: No display server detected
- **WHEN** neither `DISPLAY` nor `WAYLAND_DISPLAY` is set on the host
- **THEN** `ai-run` starts the container without clipboard forwarding and does not fail
