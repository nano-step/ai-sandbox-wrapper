## 1. Tool Configuration Inspection

- [x] 1.1 Add `config tool <tool>` subcommand to `bin/cli.js`.
- [x] 1.2 Implement helper to map tools to their primary config files.
- [x] 1.3 Add logic to find and display config file paths (host-side).
- [x] 1.4 Add `--show` flag to cat the config file content.

## 2. Container Addon Fixes

- [x] 2.1 Refactor `lib/install-base.sh` to ensure `uipro` and `specify` are in `/usr/local/bin`.
- [x] 2.2 Update `dockerfiles/base/Dockerfile` to include `/usr/local/bin` explicitly if needed.
- [x] 2.3 Rebuild base image and verify command availability for `agent` user.

## 3. Documentation

- [x] 3.1 Update `README.md` with instructions for the new `npx` config command.
