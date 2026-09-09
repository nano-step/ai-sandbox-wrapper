# Change: Add Port Exposure and Ruby/Rails Support

## Why

AI coding tools often need to run web servers, APIs, or development servers during development workflows. Currently, containers have no port exposure capability, preventing tools from serving web applications. Additionally, Ruby/Rails developers cannot use the sandbox for Rails development without Ruby runtime support.

## What Changes

### Port Exposure Feature
- Add `PORT` environment variable support to `bin/ai-run` for runtime port mapping
- Support single port (`PORT=3000`) and multiple ports (`PORT=3000,5555,5556`)
- Support binding mode selection via `PORT_BIND` env var (`localhost` or `all`)
- Default to localhost-only binding (127.0.0.1) for security
- Document port exposure in README and help output

### Ruby/Rails Support (Optional Base Image Tool)
- Add "ruby" option to setup.sh additional tools menu (alongside spec-kit, playwright, etc.)
- Add `INSTALL_RUBY` flag handling in setup.sh (same pattern as `INSTALL_PLAYWRIGHT`)
- Add `INSTALL_RUBY=1` conditional block to `lib/install-base.sh`
- Install rbenv for Ruby version management
- Install Ruby 3.3.0 as default version
- Install Rails 8.0.2 gem
- Install common Ruby development dependencies (libssl-dev, libreadline-dev, etc.)

## Impact

- **Affected specs**: `base-image` (new Ruby requirement), new `container-runtime` spec
- **Affected code**:
  - `bin/ai-run` - Add port parsing and Docker `-p` flags
  - `setup.sh` - Add "ruby" to `ADDITIONAL_TOOL_OPTIONS`, add `INSTALL_RUBY` flag handling
  - `lib/install-base.sh` - Add Ruby/Rails installation block (same pattern as Playwright)
  - `dockerfiles/base/Dockerfile` - Generated with Ruby support when enabled
  - `README.md` - Document new features

## Security Considerations

- Port binding defaults to `127.0.0.1` (localhost only) - network access requires explicit `PORT_BIND=all`
- Ruby installation is opt-in (not installed by default)
- No changes to existing security model (CAP_DROP=ALL, non-root user, etc.)
