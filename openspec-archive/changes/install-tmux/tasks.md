## 1. Dockerfile Changes

- [x] 1.1 Add `tmux` to the apt-get install package list in `dockerfiles/base/Dockerfile` (line 9)
- [x] 1.2 Add `tmux` to the apt-get install package list in `dockerfiles/sandbox/Dockerfile` (line 9)

## 2. Verification

- [x] 2.1 Verify Dockerfile syntax is valid (no broken line continuations)
- [ ] 2.2 Rebuild base image and confirm `tmux --help` works as the `agent` user
- [ ] 2.3 Rebuild sandbox image and confirm `tmux --help` works as the `agent` user
