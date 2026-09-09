## Why

Currently, SSH private keys are copied into a cache directory and mounted as read-only files into the container at `/home/agent/.ssh`. While the mount is read-only, a compromised agent can still read the private key content (`cat ~/.ssh/id_rsa`) and exfiltrate it over the network. Once stolen, the key works forever until manually revoked.

SSH agent forwarding eliminates this risk by mounting the host's SSH agent **socket** instead of the key files. The container can use the keys for signing (git clone/push) but cannot extract the actual private key material.

## What Changes

- Detect if `SSH_AUTH_SOCK` is available on the host
- If available: mount the agent socket into the container instead of copying key files
- Still mount `known_hosts` and filtered SSH config (these are not secrets)
- If SSH agent is not available: fall back to current key-copy behavior with a security warning
- On macOS Docker Desktop: use the special socket path `/run/host-services/ssh-auth.sock`
- Update the interactive prompt to inform users about the security improvement

## Capabilities

### New Capabilities

- `ssh-agent-forwarding`: Forward host SSH agent socket into container so private keys never enter the container

### Modified Capabilities

- `git-access-control`: SSH key selection UI still works but now prefers agent forwarding when available; falls back to key copy when agent is unavailable

## Impact

- **bin/ai-run**: Modify SSH mounting logic (~lines 1200-1430) to prefer agent socket over key copy
- **Security**: Private keys no longer readable inside container when agent forwarding is active
- **Compatibility**: Falls back to current behavior if SSH agent is not running
- **macOS**: Requires Docker Desktop socket path detection
- **Linux**: Uses standard `$SSH_AUTH_SOCK` path
