## 1. Add --expose Flag to Flag Parsing

- [x] 1.1 Add `--expose|-e` case to flag parsing block (lines 13-32) with EXPOSE_ARG variable
- [x] 1.2 Initialize EXPOSE_PORTS array after flag parsing section
- [x] 1.3 Parse comma-separated ports from EXPOSE_ARG into EXPOSE_PORTS array
- [x] 1.4 Validate with `bash -n bin/ai-run` after changes

## 2. Refactor PORT_MAPPINGS to Use EXPOSE_PORTS

- [x] 2.1 Create `declare -A EXPOSE_PORTS_MAP` associative array for deduplication
- [x] 2.2 Add ports from --expose flag to EXPOSE_PORTS_MAP
- [x] 2.3 Add ports from PORT env var to EXPOSE_PORTS_MAP (with deprecation warning)
- [x] 2.4 Refactor PORT_MAPPINGS construction to iterate over EXPOSE_PORTS_MAP keys
- [x] 2.5 Preserve existing PORT_BIND behavior (localhost vs all interfaces)
- [x] 2.6 Preserve existing invalid port validation and warning messages

## 3. Implement Web Command Detection

- [x] 3.1 Create `detect_opencode_web()` function that checks if TOOL is "opencode" and TOOL_ARGS contains "web"
- [x] 3.2 Create `parse_port_from_args()` function to extract --port value from TOOL_ARGS (supports --port N and --port=N)
- [x] 3.3 Create `has_hostname_arg()` function to check if --hostname is already in TOOL_ARGS
- [x] 3.4 Insert web detection logic at line ~1216 (after config setup, before PORT_MAPPINGS)
- [x] 3.5 Default to port 4096 when web detected but no --port specified

## 4. Implement Hostname Injection

- [x] 4.1 Add hostname injection logic: if web detected and no --hostname in TOOL_ARGS, append "--hostname 0.0.0.0"
- [x] 4.2 Ensure injection happens before Docker command construction
- [x] 4.3 Test that user-specified --hostname is preserved (not overwritten)

## 5. Implement Port Combination Logic

- [x] 5.1 Add auto-detected port to EXPOSE_PORTS_MAP (after web detection)
- [x] 5.2 Ensure duplicate ports are handled (same port from --expose and --port)
- [x] 5.3 Verify combined ports respect PORT_BIND setting

## 6. Implement Port Conflict Detection

- [x] 6.1 Create `check_port_in_use()` function using `lsof -i :PORT` (cross-platform: macOS/Linux)
- [x] 6.2 Add fallback to `netstat -tuln | grep :PORT` if lsof unavailable
- [x] 6.3 Create `get_port_process_info()` function to extract process name and PID
- [x] 6.4 Check Docker containers for port conflicts: `docker ps --format "{{.Ports}}" | grep PORT`
- [x] 6.5 Insert port conflict check after EXPOSE_PORTS_MAP is populated, before PORT_MAPPINGS construction
- [x] 6.6 Exit with error message if any port is in use: `❌ ERROR: Port <port> is already in use by <process> (PID: <pid>)`
- [x] 6.7 Add warning if port check tools unavailable: `⚠️ WARNING: Cannot check port availability (lsof/netstat not found)`

## 7. Add User Feedback Messages

- [x] 7.1 Add detection message: `🌐 Detected web command. Auto-exposing port <port>.`
- [x] 7.2 Add URL message: `🌐 Web UI available at http://localhost:<port>`
- [x] 7.3 Add deprecation warning for PORT env var: `⚠️ WARNING: PORT environment variable is deprecated. Use --expose flag instead.`
- [x] 7.4 Update debug output to show port source (--expose, PORT env, or auto-detected)

## 8. Testing

- [ ] 8.1 Test basic web detection: `ai-run opencode web` exposes port 4096
- [ ] 8.2 Test custom port: `ai-run opencode web --port 8080` exposes port 8080
- [ ] 8.3 Test equals-style port: `ai-run opencode web --port=8080` exposes port 8080
- [ ] 8.4 Test --expose flag: `ai-run opencode --expose 3000` exposes port 3000
- [ ] 8.5 Test combined ports: `ai-run opencode --expose 3000 web --port 4096` exposes both
- [ ] 8.6 Test duplicate handling: `ai-run opencode --expose 4096 web --port 4096` exposes 4096 once
- [ ] 8.7 Test PORT deprecation: `PORT=3000 ai-run opencode` shows warning and works
- [ ] 8.8 Test hostname preservation: `ai-run opencode web --hostname 127.0.0.1` keeps user hostname
- [ ] 8.9 Test non-web command: `ai-run opencode` does NOT auto-expose ports
- [ ] 8.10 Test port conflict detection: start a server on port 3000, then `ai-run opencode --expose 3000` should fail with helpful message
- [ ] 8.11 Test port conflict with Docker container: run container on port 3000, then test conflict detection

## 9. Documentation

- [x] 9.1 Update README.md port exposure section with --expose flag examples
- [x] 9.2 Add web auto-detection documentation to README.md
- [x] 9.3 Document deprecation of PORT environment variable
- [x] 9.4 Add examples showing combined usage (--expose + web --port)
- [x] 9.5 Document port conflict detection behavior and error messages
