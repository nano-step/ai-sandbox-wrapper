## ADDED Requirements

### Requirement: Ruby Runtime Support
The base image build system SHALL support optional installation of Ruby runtime and Rails framework via the `INSTALL_RUBY` environment variable.

#### Scenario: Ruby installation enabled
- **WHEN** `INSTALL_RUBY=1` is set during base image build
- **THEN** the following Ruby build dependencies SHALL be installed:
  - libssl-dev (OpenSSL development files)
  - libreadline-dev (Readline library)
  - zlib1g-dev (Compression library)
  - libyaml-dev (YAML parsing)
  - libffi-dev (Foreign function interface)
  - libgdbm-dev (GNU database manager)
  - libncurses5-dev (Terminal handling)
- **AND** rbenv SHALL be installed for Ruby version management
- **AND** ruby-build plugin SHALL be installed for compiling Ruby
- **AND** Ruby 3.3.0 SHALL be installed and set as global default
- **AND** Rails 8.0.2 gem SHALL be installed
- **AND** Bundler gem SHALL be installed

#### Scenario: Ruby installation disabled (default)
- **WHEN** `INSTALL_RUBY` is not set or set to `0`
- **THEN** no Ruby dependencies SHALL be installed
- **AND** the base image size SHALL remain unchanged

#### Scenario: Ruby verification
- **WHEN** Ruby is installed in the container
- **THEN** running `ruby --version` SHALL show version 3.3.0
- **AND** running `rails --version` SHALL show version 8.0.2
- **AND** running `bundle --version` SHALL succeed
- **AND** running `gem --version` SHALL succeed

#### Scenario: Rails project creation
- **WHEN** Ruby and Rails are installed in the container
- **THEN** running `rails new myapp` SHALL successfully create a new Rails application
- **AND** the created application SHALL be runnable with `rails server`
