## 1. Dockerfile Update

- [x] 1.1 Add `ripgrep` to apt-get install list in `lib/install-base.sh`

## 2. Build and Test

- [x] 2.1 Rebuild base image with `bash lib/install-base.sh` *(run on host)*
- [x] 2.2 Rebuild OpenCode image with `bash lib/install-opencode.sh` *(run on host)*
- [x] 2.3 Verify ripgrep is available: `docker run --rm ai-base:latest rg --version` *(run on host)*
- [x] 2.4 Test OpenCode file search works in sandbox environment *(run on host)*
