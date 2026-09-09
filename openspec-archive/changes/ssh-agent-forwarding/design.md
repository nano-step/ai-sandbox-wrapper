## Context

The SSH handling in `bin/ai-run` (lines 1140-1430) currently copies selected private keys to `~/.ai-sandbox/shared/git/ssh/` and mounts them read-only at `/home/agent/.ssh`. The key selection UI (`ssh-key-selector.sh`) and config filtering (`setup-ssh-config`) are well-designed and should be preserved for the fallback path.

## Goals / Non-Goals

**Goals:**
- Prefer SSH agent socket forwarding when `SSH_AUTH_SOCK` is available
- Fall back to current key-copy behavior when agent is unavailable
- Still mount `known_hosts` and filtered SSH config (not secrets)
- Handle macOS Docker Desktop socket path differences
- Preserve the existing key selection UI for the fallback path

**Non-Goals:**
- Removing the key-copy fallback entirely (some users don't use ssh-agent)
- Changing the git access control prompt (choices 1-5)
- Modifying `ssh-key-selector.sh` or `setup-ssh-config`

## Decisions

### Detect and prefer SSH agent socket
**Decision**: At the point where SSH keys would be copied, first check if `SSH_AUTH_SOCK` is set and the socket exists. If yes, mount the socket instead of copying keys. If no, fall back to current behavior.

**Detection logic:**
```bash
# Check for SSH agent socket
get_ssh_agent_socket() {
  # macOS Docker Desktop: special socket path
  if [[ "$(uname)" == "Darwin" ]] && [[ -S "/run/host-services/ssh-auth.sock" ]]; then
    echo "/run/host-services/ssh-auth.sock"
    return 0
  fi
  # Standard SSH agent socket
  if [[ -n "$SSH_AUTH_SOCK" ]] && [[ -S "$SSH_AUTH_SOCK" ]]; then
    echo "$SSH_AUTH_SOCK"
    return 0
  fi
  return 1
}
```

### Mount pattern for agent forwarding
**Decision**: When agent is available, mount socket + known_hosts + config (no keys):
```bash
GIT_MOUNTS="$GIT_MOUNTS -v $AGENT_SOCK:/ssh-agent:ro"
GIT_MOUNTS="$GIT_MOUNTS -e SSH_AUTH_SOCK=/ssh-agent"
# Still mount known_hosts and config if available
```

### Fallback with warning
**Decision**: When agent is not available, use current key-copy behavior but print a warning:
```
⚠️  SSH agent not detected. Falling back to key file mounting.
   For better security, start ssh-agent before running ai-run:
   eval "$(ssh-agent -s)" && ssh-add
```

## Risks / Trade-offs

- **macOS socket path**: Docker Desktop uses `/run/host-services/ssh-auth.sock` which may change between versions. Mitigation: check both paths.
- **Passphrase-protected keys**: Must be added to agent first (`ssh-add`). Users who rely on passphrase prompts will need to adapt.
- **Agent not running**: Some users don't use ssh-agent. Fallback ensures they're not broken.
