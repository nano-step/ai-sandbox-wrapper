# Design: Port Exposure and Ruby/Rails Support

## Context

The AI Sandbox Wrapper currently runs containers without any port exposure, which limits use cases for web development. Additionally, Ruby/Rails developers cannot use the sandbox effectively without Ruby runtime support.

**Stakeholders:**
- AI tool users who develop web applications
- Ruby/Rails developers wanting sandboxed AI assistance
- Security-conscious users who need controlled port exposure

## Goals / Non-Goals

**Goals:**
- Enable runtime port exposure via environment variable
- Support multiple simultaneous port mappings
- Provide secure defaults (localhost-only binding)
- Add optional Ruby/Rails support to base image
- Maintain backward compatibility (no ports exposed by default)

**Non-Goals:**
- Automatic port detection (user must specify ports)
- Port range syntax (e.g., `3000-3010`) - keep it simple
- Ruby version switching at runtime (rbenv is available but version is fixed at build time)
- Full Rails development environment (database servers, Redis, etc.)

## Decisions

### Decision 1: PORT Environment Variable Syntax

**What:** Use comma-separated port list: `PORT=3000,5555,5556`

**Why:**
- Simple and intuitive
- Consistent with common patterns (e.g., EXPOSE in Dockerfile)
- Easy to parse in bash

**Alternatives considered:**
- JSON array (`PORT='[3000,5555]'`) - harder to type, overkill
- Repeated flags (`-p 3000 -p 5555`) - requires wrapper script changes
- Config file - too complex for simple use case

### Decision 2: Port Binding Security

**What:** Default to localhost (127.0.0.1), allow `PORT_BIND=all` for network access

**Why:**
- Security by default - prevents accidental network exposure
- Explicit opt-in for network access
- Matches code-server pattern in existing codebase

**Implementation:**
```bash
# Default (localhost only)
PORT=3000 ai-run opencode

# Network accessible (explicit)
PORT=3000 PORT_BIND=all ai-run opencode
```

### Decision 3: Ruby Installation via rbenv

**What:** Use rbenv + ruby-build for Ruby version management

**Why:**
- Industry standard for Ruby version management
- Allows future flexibility for different Ruby versions
- Clean installation without system Ruby conflicts
- Well-documented and maintained

**Alternatives considered:**
- System Ruby via apt - outdated versions, harder to manage
- RVM - heavier, more complex
- asdf - good but adds another tool to learn

### Decision 4: Fixed Ruby/Rails Versions

**What:** Install Ruby 3.3.0 and Rails 8.0.2 at build time

**Why:**
- Predictable, reproducible builds
- Latest stable versions as of proposal date
- Users can rebuild with different versions if needed

**Version selection rationale:**
- Ruby 3.3.0: Latest stable with YJIT improvements
- Rails 8.0.2: Latest stable with Hotwire, Turbo, Stimulus

## Risks / Trade-offs

### Risk 1: Image Size Increase
- **Risk:** Ruby + Rails adds ~500MB to base image
- **Mitigation:** Installation is opt-in via `INSTALL_RUBY=1`
- **Trade-off:** Users who need Ruby accept larger image size

### Risk 2: Port Exposure Security
- **Risk:** Users might accidentally expose ports to network
- **Mitigation:** 
  - Default to localhost-only binding
  - Display warning when `PORT_BIND=all` is used
  - Document security implications

### Risk 3: Ruby Build Time
- **Risk:** Ruby compilation takes 5-10 minutes
- **Mitigation:** 
  - Pre-built images in GitLab registry can include Ruby
  - One-time cost during setup

## Implementation Details

### Port Parsing in bin/ai-run

```bash
# Parse PORT environment variable
PORT_MAPPINGS=""
if [[ -n "${PORT:-}" ]]; then
  PORT_BIND="${PORT_BIND:-localhost}"
  BIND_ADDR="127.0.0.1"
  if [[ "$PORT_BIND" == "all" ]]; then
    BIND_ADDR="0.0.0.0"
    echo "WARNING: Ports will be accessible from network (PORT_BIND=all)"
  fi
  
  IFS=',' read -ra PORTS <<< "$PORT"
  for port in "${PORTS[@]}"; do
    # Validate port number
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
      PORT_MAPPINGS="$PORT_MAPPINGS -p $BIND_ADDR:$port:$port"
    else
      echo "WARNING: Invalid port number: $port (skipped)"
    fi
  done
fi
```

### setup.sh Changes

**Line ~318 - Add to ADDITIONAL_TOOL_OPTIONS:**
```bash
ADDITIONAL_TOOL_OPTIONS="spec-kit,ux-ui-promax,openspec,playwright,ruby"
ADDITIONAL_TOOL_DESCS="Spec-driven development toolkit,UI/UX design intelligence tool,OpenSpec - spec-driven development,Playwright browser automation (adds ~500MB),Ruby 3.3.0 + Rails 8.0.2 (adds ~500MB)"
```

**Line ~366 - Add INSTALL_RUBY initialization:**
```bash
INSTALL_SPEC_KIT=0
INSTALL_UX_UI_PROMAX=0
INSTALL_OPENSPEC=0
INSTALL_PLAYWRIGHT=0
INSTALL_RUBY=0  # Add this line
```

**Line ~379 - Add case handler:**
```bash
ruby)
  INSTALL_RUBY=1
  ;;
```

**Line ~385 - Add to export:**
```bash
export INSTALL_SPEC_KIT INSTALL_UX_UI_PROMAX INSTALL_OPENSPEC INSTALL_PLAYWRIGHT INSTALL_RUBY
```

### Ruby Installation Block in lib/install-base.sh

```bash
if [[ "${INSTALL_RUBY:-0}" -eq 1 ]]; then
  echo "Ruby 3.3.0 + Rails 8.0.2 will be installed in base image"
  ADDITIONAL_TOOLS_INSTALL+='# Install Ruby build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libyaml-dev \
    libffi-dev \
    libgdbm-dev \
    libncurses5-dev \
    && rm -rf /var/lib/apt/lists/*

# Install rbenv and ruby-build
RUN git clone https://github.com/rbenv/rbenv.git /usr/local/rbenv && \
    git clone https://github.com/rbenv/ruby-build.git /usr/local/rbenv/plugins/ruby-build

ENV RBENV_ROOT=/usr/local/rbenv
ENV PATH=$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH

# Install Ruby 3.3.0
RUN rbenv install 3.3.0 && rbenv global 3.3.0

# Install Rails and Bundler
RUN gem install rails -v 8.0.2 && gem install bundler
'
fi
```

## Open Questions

1. **Should we support port:container_port syntax?** (e.g., `PORT=8080:3000`)
   - Current proposal: No, keep it simple (same port inside and outside)
   - Can be added later if needed

2. **Should Ruby version be configurable at build time?**
   - Current proposal: Fixed at 3.3.0
   - Users can modify install-base.sh if needed

3. **Should we add database gems (pg, mysql2) by default?**
   - Current proposal: No, keep minimal
   - Users can install via Gemfile in their projects
