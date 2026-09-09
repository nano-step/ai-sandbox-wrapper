# Implementation Tasks

## 1. Port Exposure Feature

- [x] 1.1 Add PORT environment variable parsing to `bin/ai-run`
  - Parse comma-separated port list (e.g., `PORT=3000,5555,5556`)
  - Validate port numbers (1-65535)
  - Generate Docker `-p` flags for each port

- [x] 1.2 Add PORT_BIND environment variable support
  - Support `localhost` (default) and `all` values
  - `localhost` maps to `127.0.0.1:PORT:PORT`
  - `all` maps to `0.0.0.0:PORT:PORT`

- [x] 1.3 Add debug output for port configuration
  - Show mapped ports in `AI_RUN_DEBUG=1` mode
  - Display security warning when `PORT_BIND=all`

- [x] 1.4 Update README.md with port exposure documentation
  - Add PORT and PORT_BIND to environment variables section
  - Add usage examples
  - Document security implications

## 2. Ruby/Rails Support

- [x] 2.1 Add "ruby" to setup.sh additional tools menu (line ~318)
  - Add "ruby" to `ADDITIONAL_TOOL_OPTIONS` string
  - Add description "Ruby 3.3.0 + Rails 8.0.2 (adds ~500MB)" to `ADDITIONAL_TOOL_DESCS`

- [x] 2.2 Add INSTALL_RUBY case handler in setup.sh (line ~368)
  - Add `INSTALL_RUBY=0` initialization with other flags
  - Add case statement for "ruby" that sets `INSTALL_RUBY=1`
  - Add `INSTALL_RUBY` to the export statement

- [x] 2.3 Add INSTALL_RUBY block to `lib/install-base.sh`
  - Add conditional block similar to INSTALL_PLAYWRIGHT pattern
  - Install Ruby build dependencies (libssl-dev, libreadline-dev, zlib1g-dev, etc.)
  - Install rbenv and ruby-build from GitHub

- [x] 2.4 Configure Ruby 3.3.0 installation in the Dockerfile block
  - Set RBENV_ROOT and PATH environment variables
  - Install Ruby 3.3.0 via `rbenv install 3.3.0`
  - Set as global default via `rbenv global 3.3.0`

- [x] 2.5 Install Rails 8.0.2 and Bundler
  - Add `gem install rails -v 8.0.2` to Dockerfile block
  - Add `gem install bundler` to Dockerfile block

## 3. Testing & Verification

- [ ] 3.1 Test port exposure with single port
  - Run `PORT=3000 ai-run opencode --shell`
  - Start a simple HTTP server inside container
  - Verify accessible from host at localhost:3000

- [ ] 3.2 Test port exposure with multiple ports
  - Run `PORT=3000,5555,5556 ai-run opencode --shell`
  - Verify all ports are mapped correctly

- [ ] 3.3 Test PORT_BIND=all security warning
  - Verify warning is displayed when using `all`
  - Verify ports are accessible from network

- [ ] 3.4 Test Ruby installation
  - Build base image with `INSTALL_RUBY=1`
  - Verify `ruby --version` shows 3.3.0
  - Verify `rails --version` shows 8.0.2
  - Verify `bundle --version` works

- [ ] 3.5 Test Rails new project creation
  - Run `rails new test_app` inside container
  - Verify project structure is created
  - Run `rails server` with port exposure

## 4. Documentation

- [x] 4.1 Update README.md
  - Add Port Exposure section
  - Add Ruby/Rails to Additional Tools section
  - Update environment variables table

- [ ] 4.2 Update AGENTS.md if needed
  - Document new capabilities for AI assistants
