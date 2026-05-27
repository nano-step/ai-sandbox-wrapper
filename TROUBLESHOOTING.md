# Troubleshooting Guide

## Tool Takes Long Time to Show Layout or Doesn't Appear

### Quick Diagnosis
Run the diagnostic tool to identify issues:
```bash
ai-debug
```

### Common Causes & Solutions

#### 1. **Platform Mismatch (MOST COMMON)**

**Symptom:** Tool takes 10-30+ seconds to start, or hangs completely

**Cause:** Wrong platform architecture (e.g., running x86_64 images on ARM64 Mac via slow emulation)

**Check:**
```bash
# Check your system architecture
uname -m
# arm64 or aarch64 = ARM
# x86_64 = Intel/AMD

# Check image architecture
docker image inspect ai-opencode:latest | grep Architecture
```

**Solution:**
```bash
# Rebuild images for your platform
./setup.sh  # Select tools to rebuild

# Or force correct platform
AI_RUN_PLATFORM=linux/arm64 ai-run opencode  # For ARM
AI_RUN_PLATFORM=linux/amd64 ai-run opencode  # For Intel
```

##### Sub-case: Stale `AI_RUN_PLATFORM` after switching images

**Symptom:** `ai-run` fails immediately with:

```
docker: Error response from daemon: image with reference ghcr.io/nano-step/ai-opencode:base
was found but does not provide the specified platform (linux/amd64)
```

…even though `uname -m` returns `arm64` and `docker inspect <image> --format '{{.Architecture}}'` confirms the image is `arm64`-native.

**Cause:** `AI_RUN_PLATFORM=linux/amd64` is still exported in your shell — most often because:

1. A previous `setup.sh` run wrote it to `~/.zshrc` or `~/.zshenv` and you didn't notice.
2. You exported it manually for a one-off cross-arch test and forgot to `unset` it.
3. Your terminal is running under Rosetta translation, so `uname -m` returns `x86_64` and `ai-run` auto-detects `linux/amd64` ([bin/ai-run](bin/ai-run) `PLATFORM` block).

`ai-run` then passes `--platform $AI_RUN_PLATFORM` to `docker run` unconditionally. If the image manifest does not include that platform, Docker refuses to start the container.

**Check:**
```bash
# Is it set in the current shell?
echo "AI_RUN_PLATFORM=[$AI_RUN_PLATFORM]"

# Is it in any rc file?
grep -nE 'AI_RUN_PLATFORM|DOCKER_DEFAULT_PLATFORM' \
  ~/.zshrc ~/.zshenv ~/.zprofile ~/.bashrc ~/.bash_profile 2>/dev/null

# Is your terminal Rosetta-translated? On Apple Silicon, this should return arm64:
uname -m
```

**Solution:**
```bash
# 1. Strip from all shell config files (BSD sed on macOS)
sed -i '' '/AI_RUN_PLATFORM/d;/DOCKER_DEFAULT_PLATFORM/d' \
  ~/.zshrc ~/.zshenv ~/.zprofile 2>/dev/null

# 2. Unset for the current shell
unset AI_RUN_PLATFORM DOCKER_DEFAULT_PLATFORM

# 3. Verify both sides are clean
echo "AI_RUN_PLATFORM=[$AI_RUN_PLATFORM]"
grep -nE 'AI_RUN_PLATFORM|DOCKER_DEFAULT_PLATFORM' ~/.zshrc ~/.zshenv ~/.zprofile 2>/dev/null

# 4. Retry
ai-run opencode -s
```

If `uname -m` returns `x86_64` on an Apple Silicon Mac, your terminal is Rosetta-translated. Quit your terminal app, uncheck "Open using Rosetta" in **Get Info**, relaunch, and re-test.

#### 2. **Terminal Size Not Detected**

**Symptom:** UI appears broken, text overflows, layout is corrupted

**Cause:** Container doesn't know terminal dimensions

**Check:**
```bash
# Check if terminal size is available
tput cols
tput lines
```

**Solution:**
```bash
# Manually set terminal size
export COLUMNS=120
export LINES=40
ai-run opencode

# Or resize your terminal window and retry
```

#### 3. **TTY Not Allocated**

**Symptom:** No interactive prompt, tool doesn't respond to input

**Cause:** Running in non-TTY environment (background, CI, pipe)

**Check:**
```bash
tty
# Should output: /dev/ttys000 (or similar)
# If "not a tty", you're in non-interactive mode
```

**Solution:**
```bash
# Use shell mode for better interactivity
ai-run opencode --shell

# Or check if you're piping output
ai-run opencode  # Don't use: ai-run opencode | less
```

#### 4. **Container Name Conflict**

**Symptom:** Error: "container name already in use"

**Cause:** Previous container didn't exit cleanly

**Solution:**
```bash
# List running containers
docker ps | grep opencode

# Stop and remove
docker rm -f opencode-myproject-abc123

# Or remove all AI containers
docker ps -a | grep "opencode-\|claude-\|gemini-" | awk '{print $1}' | xargs docker rm -f
```

#### 5. **Slow Volume Mounts (macOS)**

**Symptom:** Tool starts but file operations are slow

**Cause:** Docker Desktop volume sync on macOS

**Solution:**
```bash
# Already configured with :delegated flag
# For extremely large projects, consider:
# - Exclude node_modules, .git, build folders
# - Use .dockerignore

# Check current mounts
docker inspect <container-name> | grep Mounts -A 20
```

#### 6. **Missing Dependencies in Container**

**Symptom:** Tool starts but crashes or shows errors

**Check:**
```bash
# Enter container in shell mode
ai-run opencode --shell

# Check if tool is installed
which opencode
opencode --version

# Check for errors
opencode 2>&1 | head -20
```

**Solution:**
```bash
# Rebuild the image
./setup.sh  # Select the tool
```

---

## Performance Optimization

### For Development (Iterative Work)

Use **shell mode** to avoid recreating container:
```bash
ai-run opencode --shell
agent@container$ opencode
# Press Ctrl+C to stop
agent@container$ opencode  # Start again instantly
agent@container$ exit
```

### For Native Speed

Ensure platform matches:
```bash
# Add to ~/.ai-env
AI_RUN_PLATFORM=linux/arm64  # For Apple Silicon
# or
AI_RUN_PLATFORM=linux/amd64  # For Intel/AMD
```

### For Better Terminal Rendering

```bash
# Add to ~/.zshrc or ~/.bashrc
export TERM=xterm-256color
export COLORTERM=truecolor
```

---

## Diagnostic Commands

### System Check
```bash
ai-debug  # Comprehensive diagnostics
```

### Docker Status
```bash
docker ps                    # Running containers
docker images | grep ai-     # Available images
docker stats                 # Resource usage
```

### Container Inspection
```bash
# Get container name
docker ps | grep opencode

# View logs
docker logs <container-name>

# Inspect configuration
docker inspect <container-name>

# Enter running container
docker exec -it <container-name> bash
```

### Debug Mode
```bash
# Enable verbose output
AI_RUN_DEBUG=1 ai-run opencode
```

---

## Common Error Messages

### "Workspaces not configured"
```bash
# Run setup
./setup.sh

# Or manually add workspace
echo "$(pwd)" >> ~/.ai-workspaces
```

### "Image not found"
```bash
# Pull from registry
docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-opencode:latest

# Or rebuild locally
./setup.sh
```

### Wrapper launches the wrong image version (e.g. `:full-v5.1.5` after installing `:base`)

**Symptom:** You installed/pulled `:base` (or a newer version) but `ai-run` keeps launching the old `:full-vX.Y.Z` image. Pruning the image causes the next `ai-run` invocation to silently re-pull the wrong tag from `ghcr.io` and run it.

**Cause:** Three independent overrides can each force `ai-run` onto a specific registry tag, in priority order:

1. `AI_IMAGE_SOURCE=registry` + `AI_IMAGE_TAG=<old-tag>` exported in your shell
   ([bin/ai-run](bin/ai-run) image selection block). These get written to `~/.zshrc` / `~/.zshenv` by `setup.sh` when you pick the "registry" path, and are **appended without dedup** on each setup run, so they accumulate as duplicate `export` lines.
2. Stale container holding the old image alive — `ai-sandbox:latest` may already point at the new image, but a container from a prior session still references the old one, which is why `docker rmi` on the old image fails with `must be forced - container ... is using its referenced image`.
3. Floating registry tags like `:full` and `:base` on `ghcr.io/nano-step/ai-opencode` lag behind npm wrapper releases. The wrapper at `@nano-step/ai-sandbox-wrapper@5.3.x` may pull a floating tag that still resolves to a `v5.1.x` manifest.

**Check:**
```bash
# 1. What env vars are forcing the image?
env | grep -E 'AI_IMAGE_|AI_SANDBOX_'
grep -nE 'AI_IMAGE_|AI_SANDBOX_' ~/.zshrc ~/.zshenv ~/.zprofile ~/.ai-env 2>/dev/null

# 2. What does ai-sandbox:latest actually point at?
docker inspect ai-sandbox:latest --format \
  '{{.Created}}  {{.RepoTags}}  {{.Architecture}}'

# 3. Are there stale containers pinned to the old image?
docker ps -a --filter "ancestor=<old-image-id>"

# 4. Does the floating ghcr tag match the wrapper version you installed?
docker manifest inspect ghcr.io/nano-step/ai-opencode:base \
  | grep -E '"digest"|"architecture"'
```

**Solution:**
```bash
# 1. Strip the registry overrides from all shell config files (BSD sed on macOS)
sed -i '' '/AI_IMAGE_SOURCE/d;/AI_IMAGE_TAG/d;/AI_IMAGE_REGISTRY/d;/AI_SANDBOX_IMAGE/d' \
  ~/.zshrc ~/.zshenv ~/.zprofile ~/.ai-env 2>/dev/null

# 2. Unset for the current shell
unset AI_IMAGE_SOURCE AI_IMAGE_TAG AI_IMAGE_REGISTRY AI_SANDBOX_IMAGE

# 3. Verify both sides are clean
env | grep -E 'AI_IMAGE_|AI_SANDBOX_'   # must be empty
grep -nE 'AI_IMAGE_|AI_SANDBOX_' ~/.zshrc ~/.zshenv ~/.zprofile ~/.ai-env 2>/dev/null   # empty

# 4. Kill stale containers on the old image, then drop the old tags
docker ps -a --filter "ancestor=<old-image-id>" -q | xargs -r docker rm -f
docker rmi ghcr.io/nano-step/ai-opencode:full-vX.Y.Z 2>/dev/null
docker image prune -f

# 5. Confirm ai-sandbox:latest points at the desired image
docker tag ghcr.io/nano-step/ai-opencode:base ai-sandbox:latest

# 6. Retry
ai-run opencode -s
```

With `AI_IMAGE_SOURCE` unset, `ai-run` falls back to `AI_IMAGE_SOURCE=local` and resolves the image as `ai-sandbox:latest` — the canonical local tag that `setup.sh` and `lib/pull-opencode-image.sh` both maintain.

### "Permission denied"
```bash
# Fix Docker socket permissions (Linux)
sudo usermod -aG docker $USER
newgrp docker

# Restart Docker (macOS)
# Docker Desktop > Restart
```

### "Cannot connect to Docker daemon"
```bash
# Check if Docker is running
docker ps

# Start Docker Desktop (macOS/Windows)
# Or start Docker service (Linux)
sudo systemctl start docker
```

---

## Still Having Issues?

1. **Run full diagnostics:**
   ```bash
   ai-debug > diagnostics.txt
   cat diagnostics.txt
   ```

2. **Check container logs:**
   ```bash
   docker logs <container-name> 2>&1 | tail -50
   ```

3. **Try with minimal setup:**
   ```bash
   # Fresh start
   docker pull registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-opencode:latest
   cd ~/test-project
   echo "$PWD" >> ~/.ai-workspaces
   ai-run opencode --shell
   ```

4. **Report issue with:**
   - Output of `ai-debug`
   - Output of `AI_RUN_DEBUG=1 ai-run <tool>`
   - Your OS and architecture (`uname -a`)
   - Docker version (`docker --version`)
