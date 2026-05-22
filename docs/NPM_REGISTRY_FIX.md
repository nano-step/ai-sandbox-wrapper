# NPM Registry Fix for Docker Network Issues

## Problem

When running `./bin/cli.js` to install tools with `npm -g` (like Playwright, Chrome DevTools), the installation may fail with DNS resolution errors:

```
ENOTFOUND registry.npmjs.org
npm ERR! code ENOTFOUND
npm ERR! errno ENOTFOUND
npm ERR! network error at sync request to https://registry.npmjs.org/...
```

This occurs when:
1. Docker build commands don't have access to host DNS
2. Container networking is not configured with DNS servers
3. `npm install -g` tries to access npm registry but DNS lookup fails

## Root Causes

### 1. Build-time DNS Issue (Primary)
- When `docker build` runs without `--network=host`, the build environment doesn't inherit the host's DNS configuration
- Custom Docker networks require explicit DNS configuration
- npm install during build fails to resolve `registry.npmjs.org`

### 2. Runtime DNS Issue (Secondary)  
- When containers run with `--network ai-sandbox`, Docker doesn't automatically provide DNS for external lookups
- Container cannot reach npm registry to download packages

## Solution

All install scripts and build processes now include:

### 1. Build-time Fix
All `docker build` commands now include `--network=host`:
```bash
docker build ${DOCKER_NO_CACHE:+--no-cache} --network=host -t "ai-$TOOL:latest" "dockerfiles/$TOOL"
```

**Files patched:**
- `lib/install-base.sh` - Base image with npm tools
- `lib/build-sandbox.sh` - Unified sandbox build
- `lib/install-*.sh` - All individual tool installers (18 files total)

### 2. Runtime Fix  
The `bin/ai-run` script now adds explicit DNS servers for containers using custom networks:
```bash
DOCKER_ARGS+=(--dns 8.8.8.8)
DOCKER_ARGS+=(--dns 1.1.1.1)
```

**Why this works:**
- `--dns 8.8.8.8` = Google Public DNS (reliable, global)
- `--dns 1.1.1.1` = Cloudflare DNS (fallback, 1.1.1.1 for privacy)
- These override Docker's default DNS when using custom networks

## Verification

To verify the fix is working:

### Test 1: Check if npm can access registry inside container
```bash
ai-run --shell
npm view playwright  # Should show package info without errors
```

### Test 2: Build a tool and verify successful npm install
```bash
./setup.sh          # Select Playwright or Chrome DevTools
# Check installation succeeded
docker image inspect ai-sandbox:latest | grep -i playwright
```

### Test 3: Direct network test
```bash
docker run --rm --dns 8.8.8.8 --dns 1.1.1.1 \
  --network ai-sandbox \
  curlimages/curl:latest \
  curl -s https://registry.npmjs.org/playwright | head -20
# Should return JSON package data (no ENOTFOUND errors)
```

## Technical Details

### Why `--network=host` for builds?
- Allows Docker build environment to use the host's network stack
- DNS resolution works without additional configuration
- Build process can reach npm registry reliably
- No network isolation during build (acceptable since build runs locally)

### Why `--dns` flags for runtime?
- `--network ai-sandbox` creates an isolated network
- This network doesn't have built-in DNS for external services
- Explicit DNS servers tell Docker where to resolve domain names
- Google DNS (8.8.8.8) and Cloudflare DNS (1.1.1.1) are global, reliable options

### Why NOT use `--network host` for runtime?
- Breaks service discovery between containers (agents can't reach open-design daemon by hostname)
- Ports would bind to host directly (security issue)
- Service isolation would be lost
- Better to use `--dns` which solves the problem while keeping network isolation

## Fallback Troubleshooting

If you still encounter npm registry issues:

### 1. Check Docker DNS Configuration
```bash
# Inside container
cat /etc/resolv.conf
# Should show nameservers including 8.8.8.8 and 1.1.1.1
```

### 2. Test DNS directly
```bash
ai-run --shell
nslookup registry.npmjs.org
# Should resolve to an IP (not "ENOTFOUND")
```

### 3. Manual npm registry override (if needed)
```bash
ai-run --shell
npm config set registry https://registry.npmjs.org/
npm cache clean --force
npm install -g @playwright/mcp
```

### 4. Force rebuild without cache
```bash
./setup.sh  # Or use individual tools
DOCKER_NO_CACHE=1 ./setup.sh
```

### 5. Check Docker daemon network configuration
```bash
# On macOS/Linux
docker info | grep -A5 "Name Servers"
# Should show DNS servers configured
```

## References

- Docker DNS Documentation: https://docs.docker.com/config/containers/container-networking/
- Docker build --network flag: https://docs.docker.com/engine/reference/commandline/build/
- npm registry issues: https://docs.npmjs.com/cli/v6/using-npm/config
