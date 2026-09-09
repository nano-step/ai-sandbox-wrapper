## 1. Simplified Setup

- [x] 1.1 Relax workspace requirement in `setup.sh` to allow empty input.
- [x] 1.2 Ensure `setup.sh` correctly initializes `config.json` even with an empty workspace list.

## 2. Interactive Whitelisting

- [x] 2.1 Update `bin/ai-run` to call `init_config` at the start of path configuration.
- [x] 2.2 Modify the "Workspaces not configured" check to be more lenient, allowing empty whitelists.
- [x] 2.3 Verify the interactive whitelisting prompt correctly adds the current directory and persists it.

## 3. Verification

- [x] 3.1 Perform a clean install without providing any workspace paths.
- [x] 3.2 Run an AI tool in a new directory and confirm whitelisting prompt appears.
- [x] 3.3 Confirm the directory is added to `config.json` and tool executes successfully.
