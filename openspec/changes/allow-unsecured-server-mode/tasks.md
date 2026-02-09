## 1. Flag Parsing

- [x] 1.1 Add `SERVER_PASSWORD`, `PASSWORD_ENV_VAR`, and `ALLOW_UNSECURED` variables initialization after line 11
- [x] 1.2 Add `--password|-p` flag case to the while loop (lines 13-33) with argument consumption
- [x] 1.3 Add `--password-env` flag case to the while loop with argument consumption
- [x] 1.4 Add `--allow-unsecured` flag case to the while loop (boolean, no argument)

## 2. Password Resolution Logic

- [x] 2.1 Create `resolve_opencode_password()` function before `is_opencode_web_mode()` function
- [x] 2.2 Implement precedence: CLI `--password` > `--password-env` > existing `OPENCODE_SERVER_PASSWORD`
- [x] 2.3 Add error handling for `--password-env` when variable is not set (exit with error message)
- [x] 2.4 Handle password values with spaces (proper quoting)

## 3. Modify OpenCode Web Mode Section

- [x] 3.1 Update `is_opencode_web_mode` block (lines 1132-1188) to check for new flags first
- [x] 3.2 Skip interactive menu when `--password`, `--password-env`, or `--allow-unsecured` is provided
- [x] 3.3 Suppress warning message when `--allow-unsecured` is provided in non-interactive mode
- [x] 3.4 Ensure `--allow-unsecured` does not override existing `OPENCODE_SERVER_PASSWORD` from environment

## 4. Help Text and Documentation

- [x] 4.1 Add new flags to `ai-run --help` output with descriptions
- [x] 4.2 Add security note about command-line password visibility in help text
- [x] 4.3 Update README.md with new authentication flags and examples

## 5. Testing and Verification

> **Note:** These tests require Docker and should be run manually.

- [ ] 5.1 Test `--password` flag sets password correctly (verify with `docker inspect`)
- [ ] 5.2 Test `-p` short form works identically to `--password`
- [ ] 5.3 Test `--password-env` reads from specified variable
- [ ] 5.4 Test `--password-env` with missing variable shows error and exits
- [ ] 5.5 Test `--allow-unsecured` suppresses warning in non-interactive mode
- [ ] 5.6 Test `--allow-unsecured` skips menu in interactive mode
- [ ] 5.7 Test backward compatibility: no flags = existing behavior unchanged
- [ ] 5.8 Test flag precedence: CLI password overrides environment variable
