## 1. Base image plumbing

- [ ] 1.1 Add `od-status` script to `dockerfiles/base/` (and copy in Dockerfile to `/usr/local/bin/od-status`, chmod +x)
- [ ] 1.2 Add `od-health` script to `dockerfiles/base/` (and copy in Dockerfile to `/usr/local/bin/od-health`, chmod +x)
- [ ] 1.3 Verify base image still builds: `bash lib/install-base.sh`
- [ ] 1.4 Verify `od-status --help` and `od-health --help` work inside the rebuilt base image

## 2. open-design tool installer

- [ ] 2.1 Create `lib/install-open-design.sh` following the `install-{tool}.sh` pattern (header, `set -e`, snippet mode support, version pin via `OPEN_DESIGN_VERSION` env)
- [ ] 2.2 Create `dockerfiles/open-design/Dockerfile` based on `docker.io/vanjayak/open-design:latest` with `ENV OD_BIND_HOST=0.0.0.0`, `EXPOSE 7456`
- [ ] 2.3 Confirm Docker build succeeds: `bash lib/install-open-design.sh` produces `ai-open-design:latest`
- [ ] 2.4 Smoke test image standalone: `docker run --rm -e OD_API_TOKEN=test123 -p 7456:7456 ai-open-design:latest` → `curl http://localhost:7456/api/health` returns 200
- [ ] 2.5 Add tool entry to `setup.sh` tool selection menu (alphabetically sorted)
- [ ] 2.6 Add tool entry to `.gitlab-ci.yml` build matrix

## 3. ai-run lifecycle dispatch

- [ ] 3.1 In `bin/ai-run`, detect `open-design` as the first positional argument and route to a new dispatcher function `dispatch_open_design()` instead of the generic tool path
- [ ] 3.2 Implement `init` subcommand: ensure network, ensure volume, generate or reuse token, write to `~/.ai-sandbox/env`, chmod 600
- [ ] 3.3 Implement `start` subcommand: ensure prerequisites, run daemon container detached with `--name ai-open-design --network ai-sandbox --restart unless-stopped -v ai-open-design-data:/app/.od -e OD_API_TOKEN=$OD_API_TOKEN`; support optional `--expose` flag to add `-p 7456:7456`
- [ ] 3.4 Implement `stop` subcommand: `docker stop ai-open-design` (ignore if already stopped); preserve container so config flags survive
- [ ] 3.5 Implement `restart` subcommand: stop + start with same flags
- [ ] 3.6 Implement `status` subcommand: print container state (`docker inspect`), port mapping, token presence in env file (mask), and run `od-health` via `docker exec` (or curl from host if `--expose`)
- [ ] 3.7 Implement `logs` subcommand: `docker logs [-f] ai-open-design` (passthrough `-f`/`--follow`)
- [ ] 3.8 Help text: `ai-run open-design --help` lists all subcommands with one-line descriptions

## 4. Network + env injection for all tools

- [ ] 4.1 Add `ensure_network()` helper in `bin/ai-run` that creates `ai-sandbox` Docker network if missing
- [ ] 4.2 Modify the generic `docker run` invocation in `bin/ai-run` to always include `--network ai-sandbox` (after calling `ensure_network`)
- [ ] 4.3 Verify existing tools still launch correctly: `ai-run opencode --version`, `ai-run claude --version`
- [ ] 4.4 Confirm two simultaneously running agent containers can resolve each other's container names (smoke test: `ai-run opencode` in one terminal, `ai-run claude` in another, then `getent hosts ai-claude` inside opencode container)

## 5. Volume sharing (read-only artifacts)

- [ ] 5.1 Modify `bin/ai-run` so agent containers mount `ai-open-design-data` volume at `/workspace/.od` with `:ro` mode (only when volume exists — skip otherwise to keep ai-run usable before init)
- [ ] 5.2 Verify agent can read artifacts: after generating one via daemon, confirm `ls /workspace/.od/projects/` inside agent container shows it
- [ ] 5.3 Verify agent cannot write: `touch /workspace/.od/test` inside agent container fails with permission error

## 6. Token + URL injection

- [ ] 6.1 Confirm existing `~/.ai-sandbox/env` mount logic in `bin/ai-run` picks up new `OD_API_TOKEN` and `OD_DAEMON_URL` lines without modification
- [ ] 6.2 If env file doesn't exist yet, `ai-run open-design init` should create it (not just append)
- [ ] 6.3 Verify env vars visible inside agent: `ai-run opencode -- bash -c 'echo $OD_API_TOKEN $OD_DAEMON_URL'`

## 7. End-to-end smoke test

- [ ] 7.1 From a clean state: `ai-run open-design init`, then `ai-run open-design start`, then `ai-run open-design status` shows "running"
- [ ] 7.2 Start an OpenCode container: `ai-run opencode` (or any agent), open a shell, run `od-health` → 200 OK
- [ ] 7.3 Issue a simple chat: `curl -X POST "$OD_DAEMON_URL/api/chat" -H "Authorization: Bearer $OD_API_TOKEN" -H "Content-Type: application/json" -d '{"agentId":"claude","message":"create a hello world HTML page"}'` and observe SSE stream
- [ ] 7.4 Verify result artifact appears in `/workspace/.od/projects/.../` (read-only mount)
- [ ] 7.5 Stop daemon: `ai-run open-design stop`. Agent shell `od-health` now fails with connection refused — confirm graceful error message
- [ ] 7.6 Restart daemon: `ai-run open-design start`. `od-health` works again **without** restarting the agent container (validates the "morning don't need OD, afternoon do" requirement)

## 8. Documentation

- [ ] 8.1 Add `docs/open-design.md` covering: prerequisites, init/start/stop workflow, calling the API from an agent shell with `curl`, troubleshooting (network not found, token mismatch, volume permission)
- [ ] 8.2 Update `README.md` "Adding a New Tool" or quick-reference table to mention open-design as a service-type tool (vs ephemeral CLIs)
- [ ] 8.3 Add a short note in `AGENTS.md` about the service-tool pattern (so future tools follow the same shape)

## 9. CI / Release

- [ ] 9.1 Ensure CI pipeline builds `ai-open-design:latest` and pushes to registry (alongside other tool images)
- [ ] 9.2 Commit changes following Conventional Commits: `feat(open-design): integrate open-design daemon as service-type tool`
- [ ] 9.3 Open PR with link to this OpenSpec change and the corresponding GitHub issue
- [ ] 9.4 After merge: archive this change via `openspec archive add-open-design-integration`
