## Context

The `ai-run` wrapper script manages Docker container execution for AI tools. When running `opencode web` or `opencode serve`, it currently handles server password configuration through:

1. **Environment variable check**: Uses `OPENCODE_SERVER_PASSWORD` if already set
2. **Interactive prompt**: In TTY mode, offers 3 options (generate, custom, none)
3. **Non-interactive fallback**: Shows warning about unsecured server

The current implementation (lines 1118-1188 in `bin/ai-run`) works well for interactive use but lacks CLI flags for scripted/automated scenarios.

**Existing flag parsing pattern** (lines 13-33):
```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    --shell|-s) SHELL_MODE=true; shift ;;
    --network|-n) NETWORK_FLAG=true; shift; ... ;;
    *) TOOL_ARGS+=("$1"); shift ;;
  esac
done
```

## Goals / Non-Goals

**Goals:**
- Provide CLI flags to set server password without editing config files
- Allow explicit opt-in to unsecured mode without warnings
- Maintain backward compatibility with existing behavior
- Follow established flag parsing patterns in `ai-run`

**Non-Goals:**
- Changing OpenCode's native authentication behavior
- Adding persistent password storage (use `~/.ai-sandbox/env` for that)
- Supporting username customization via flag (use `OPENCODE_SERVER_USERNAME` env var)
- Modifying interactive mode behavior (keep existing 3-option menu)

## Decisions

### 1. Flag Names and Short Forms

**Decision:** Use `--password` / `-p`, `--password-env`, and `--allow-unsecured`

**Rationale:**
- `--password` / `-p`: Standard convention for password flags (matches `mysql -p`, `ssh-keygen -p`)
- `--password-env`: Explicit about reading from environment, avoids confusion with `--password`
- `--allow-unsecured`: Clear intent, matches security-conscious naming (not `--insecure` which sounds dangerous)

**Alternatives considered:**
- `--server-password`: Too verbose, `--password` is sufficient in context
- `--no-auth`: Negative framing, `--allow-unsecured` is more explicit about what you're opting into
- `-P` for password: Conflicts with potential future port flag, `-p` is more standard

### 2. Flag Precedence Order

**Decision:** CLI flags > Environment variable > Interactive prompt

```
1. --password <value>      → Use this password
2. --password-env <VAR>    → Read from $VAR
3. OPENCODE_SERVER_PASSWORD env var → Use existing behavior
4. Interactive prompt (if TTY) → Show menu
5. Non-interactive fallback → Show warning (unless --allow-unsecured)
```

**Rationale:** CLI flags should always win for scriptability. This matches standard Unix conventions where command-line arguments override environment variables.

### 3. Flag Parsing Location

**Decision:** Add new flags to existing `while` loop at lines 13-33

**Rationale:**
- Consistent with existing `--shell` and `--network` flag handling
- Flags are parsed before tool-specific logic runs
- New variables (`SERVER_PASSWORD`, `PASSWORD_ENV_VAR`, `ALLOW_UNSECURED`) set early

### 4. Password Handling Security

**Decision:** 
- Accept password on command line (user's choice to use it)
- Do NOT echo password to terminal
- Pass to container via `-e OPENCODE_SERVER_PASSWORD=<value>`

**Rationale:**
- Command-line passwords are visible in `ps` output, but this is standard practice (mysql, curl, etc.)
- Users who care about security can use `--password-env` or the env file
- Warning in help text about command-line visibility

### 5. Interaction with Existing Modes

**Decision:** New flags only affect non-interactive behavior

| Scenario | Behavior |
|----------|----------|
| `--password` + interactive | Use password, skip menu |
| `--password` + non-interactive | Use password, no warning |
| `--allow-unsecured` + interactive | Skip menu, no password |
| `--allow-unsecured` + non-interactive | No warning, no password |
| No flags + interactive | Show existing menu (unchanged) |
| No flags + non-interactive | Show warning (unchanged) |

**Rationale:** Flags provide explicit control; absence of flags preserves existing behavior.

## Risks / Trade-offs

### Risk: Password visible in process list
**Mitigation:** Document in help text. Recommend `--password-env` for sensitive environments.

### Risk: `--allow-unsecured` misuse
**Mitigation:** 
- Name clearly indicates security implication
- Help text warns about network exposure
- Only suppresses warning, doesn't change OpenCode behavior

### Risk: Flag conflicts with future OpenCode flags
**Mitigation:** These are `ai-run` wrapper flags, parsed before passing args to OpenCode. No conflict possible.

### Trade-off: No short form for `--allow-unsecured`
**Accepted:** Security-related flags should be explicit. Typing `--allow-unsecured` is intentional friction.

### Trade-off: No `--username` flag
**Accepted:** Username rarely changes. Use `OPENCODE_SERVER_USERNAME` env var for the rare case.
