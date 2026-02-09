## Why

OpenCode's "@" file search feature fails inside the Docker sandbox because the bundled ripgrep (`rg`) binary is a macOS Mach-O executable, but the container runs Linux ARM64. When OpenCode tries to execute the host-mounted `~/.local/share/opencode/bin/rg`, it fails with "Exec format error" (ENOEXEC), completely breaking file search functionality.

## What Changes

- Install `ripgrep` package in the base Docker image so a Linux-native binary is always available
- Ensure the system ripgrep is accessible in PATH before OpenCode's bundled binary
- This enables OpenCode's file search, glob patterns, and "@" file references to work correctly in sandboxed environments

## Capabilities

### New Capabilities
- `ripgrep-support`: Base image includes ripgrep binary for file search operations, ensuring cross-platform compatibility when host tools mount architecture-incompatible binaries

### Modified Capabilities
- `base-image`: Add ripgrep to the list of installed packages in the base Dockerfile

## Impact

- **Affected Files**: `dockerfiles/base/Dockerfile`
- **Image Size**: Minimal increase (~2-3MB for ripgrep package)
- **Compatibility**: Fixes OpenCode file search on all host platforms (macOS Intel, macOS ARM, Linux)
- **No Breaking Changes**: Existing functionality preserved; this is purely additive
