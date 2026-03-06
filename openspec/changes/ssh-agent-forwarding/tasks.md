## 1. Add SSH agent detection function

- [x] 1.1 Add `get_ssh_agent_socket()` function to `bin/ai-run` before the Git access control section (~line 1140)
- [x] 1.2 Function checks macOS Docker Desktop socket path first, then standard `$SSH_AUTH_SOCK`
- [x] 1.3 Returns socket path on success, returns 1 on failure

## 2. Add agent-forwarding mount helper

- [x] 2.1 Add `setup_ssh_agent_forwarding()` function that sets `GIT_MOUNTS` with socket mount + `SSH_AUTH_SOCK` env var
- [x] 2.2 Function also mounts `known_hosts` and filtered SSH config (not keys) at `/home/agent/.ssh/`
- [x] 2.3 Function prints "🔒 SSH agent forwarding active (keys never enter container)"

## 3. Modify saved-keys path (previously-allowed workspace)

- [x] 3.1 In the saved-keys block (~lines 1200-1269), check for agent socket FIRST
- [x] 3.2 If agent available: call `setup_ssh_agent_forwarding()` instead of copying keys
- [x] 3.3 If agent unavailable: fall back to existing key-copy logic with warning

## 4. Modify interactive prompt path (new workspace)

- [x] 4.1 In the interactive block (~lines 1298-1430), check for agent socket FIRST
- [x] 4.2 If agent available: skip `ssh-key-selector.sh`, call `setup_ssh_agent_forwarding()`
- [x] 4.3 If agent unavailable: use existing key selection + copy flow with warning
- [x] 4.4 Preserve all workspace saving logic (choices 2, 5 save to config.json)

## 5. Pass SSH_AUTH_SOCK to docker run

- [x] 5.1 Add a variable (e.g., `SSH_AGENT_ENV`) to hold `-e SSH_AUTH_SOCK=/ssh-agent` when agent forwarding is active
- [x] 5.2 Include `$SSH_AGENT_ENV` in the docker run command (~line 2252)

## 6. Verification

- [x] 6.1 Validate `bin/ai-run` syntax with `bash -n`
- [x] 6.2 Verify the docker run command includes both `$GIT_MOUNTS` and `$SSH_AGENT_ENV`
