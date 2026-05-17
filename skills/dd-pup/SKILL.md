---
name: dd-pup
description: "Datadog CLI (pup) for AI agents. OAuth2 auth with token refresh. Query logs, metrics, monitors, traces, and more."
compatibility: "OpenCode with pup binary installed"
metadata:
  author: datadog-labs
  version: "1.0.0"
  repository: https://github.com/DataDog/pup
---

# pup (Datadog CLI)

Pup CLI for Datadog API operations. Supports OAuth2 and API key auth.

## Quick Reference

| Task | Command |
|------|---------|
| Search error logs | `pup logs search --query "status:error" --from 1h` |
| List monitors | `pup monitors list` |
| Create downtime | `pup downtime create --file downtime.json` |
| Find slow traces | `pup traces search --query="@duration:>500000000" --from="1h"` |
| List incidents | `pup incidents list` |
| Query metrics | `pup metrics query --query "avg:system.cpu.user{*}"` |
| List hosts | `pup infrastructure hosts list` |
| Check SLOs | `pup slos list` |
| On-call teams | `pup on-call teams list` |
| Security signals | `pup security signals list --query "*" --from 24h` |
| Check auth | `pup auth status` |
| Refresh token | `pup auth refresh` |

## Prerequisites

```bash
# Install pup via Homebrew (recommended)
brew tap datadog-labs/pack
brew install pup

# Or build from source
cargo install --git https://github.com/DataDog/pup
```

## Auth

```bash
pup auth login    # OAuth2 browser flow (recommended)
pup auth status   # Check token validity
pup auth refresh  # Refresh expired token (no browser)
pup auth logout   # Clear credentials
```

**⚠️ Tokens expire (~1 hour)**. If a command fails with 401/403:
```bash
pup auth refresh  # Try refresh first
pup auth login    # If refresh fails, full re-auth
```

### Headless/CI (no browser)

```bash
export DD_API_KEY=your-api-key
export DD_APP_KEY=your-app-key
export DD_SITE=datadoghq.com  # or datadoghq.eu, etc.
```

## Command Reference

### Monitors

```bash
pup monitors list --limit 10
pup monitors list --tags "env:prod"
pup monitors get 12345
pup monitors search --query "High CPU"
pup monitors create --file monitor.json
pup monitors delete 12345
```

### Logs

```bash
pup logs search --query "status:error" --from 1h
pup logs search --query "service:payment-api" --from 1h --limit 100
pup logs aggregate --query "service:api" --compute count --from 1h
```

### Metrics

```bash
pup metrics query --query "avg:system.cpu.user{*}" --from 1h
pup metrics list --filter "system.*"
```

### APM / Services

```bash
pup apm services list --env production
pup apm services stats --env production
pup apm dependencies list --env production
```

### Traces

```bash
pup traces search --query="service:api-gateway" --from="1h"
pup traces search --query="service:api @duration:>1000000000" --from="1h"
pup traces aggregate --query="service:api" --compute="avg(@duration)" --group-by="resource_name" --from="1h"
```

### Infrastructure / Hosts

```bash
pup infrastructure hosts list
pup infrastructure hosts list --filter "env:prod"
```

### Dashboards

```bash
pup dashboards list
pup dashboards get abc-123
pup dashboards create --file dashboard.json
```

### SLOs

```bash
pup slos list
pup slos get slo-123
pup slos status slo-123 --from 30d --to now
```

### Security

```bash
pup security signals list --query "*" --from 24h
pup security rules list
```

### Live Debugger

```bash
pup debugger context my-svc --env prod
pup symdb search --service my-svc --query MyController --view probe-locations
pup debugger probes create --service my-svc --env prod \
  --probe-location "com.example.MyController:handleRequest" \
  --capture "request.id" --ttl 1h
pup debugger probes watch --fields "message,captures,timestamp" --timeout 60
```

## Subcommand Discovery

```bash
pup --help            # List all commands
pup <cmd> --help      # Command-specific help
pup agent schema      # Machine-readable output
```

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| 401 Unauthorized | Token expired | `pup auth refresh` |
| 403 Forbidden | Missing scope | Check app key permissions |
| 404 Not Found | Wrong ID/resource | Verify resource exists |
| Rate limited | Too many requests | Add delays between calls |

## Sites

| Site | `DD_SITE` value |
|------|-----------------|
| US1 (default) | `datadoghq.com` |
| US3 | `us3.datadoghq.com` |
| US5 | `us5.datadoghq.com` |
| EU1 | `datadoghq.eu` |
| AP1 | `ap1.datadoghq.com` |
| US1-FED | `ddog-gov.com` |

## Detection

Before using pup commands, verify it's installed:
```bash
pup --version
```

If `pup` is not found, skip this skill.
