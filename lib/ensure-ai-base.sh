#!/usr/bin/env bash
# ensure-ai-base.sh — Ensure ai-base:<preset> image is available locally.
#
# Modes:
#   BASE_IMAGE_MODE=local (default): only verify local tag exists; never pull.
#   BASE_IMAGE_MODE=registry: pull from registry when local is missing/stale.
#
# Knobs:
#   BASE_IMAGE_PRESET         base | full            (default: $1 positional arg, fallback 'base')
#   AI_IMAGE_BASE_REGISTRY    ghcr.io owner / repo   (default: ghcr.io/nano-step/ai-base)
#   AI_IMAGE_BASE_TAG         rolling/sha/version    (default: $BASE_IMAGE_PRESET)
#   BASE_IMAGE_ALLOW_LOCAL_BUILD  0 | 1              (default: 1)
#
# Usage:
#   bash lib/ensure-ai-base.sh <preset>
#   bash "$(dirname "$0")/ensure-ai-base.sh" "${BASE_IMAGE_PRESET:-base}"
#
# Exit codes:
#   0  Local image present (or pull / fallback succeeded)
#   1  Hard failure (local missing in local-mode, or pull failed with fallback disabled)
#
# Refs:
#   openspec/changes/publish-ai-base-image-ghcr/specs/ai-base-registry-image/spec.md

set -euo pipefail

# Defensive HOME fallback (independent-review finding L2: set -u would otherwise
# abort when HOME is unset in a subshell / CI environment).
HOME="${HOME:-$(eval echo ~)}"

# ---- Args & defaults ------------------------------------------------------

PRESET="${1:-${BASE_IMAGE_PRESET:-base}}"
MODE="${BASE_IMAGE_MODE:-local}"
ALLOW_LOCAL_BUILD="${BASE_IMAGE_ALLOW_LOCAL_BUILD:-1}"
REGISTRY="${AI_IMAGE_BASE_REGISTRY:-ghcr.io/nano-step/ai-base}"
# Tag defaults to the preset (rolling tag); override with AI_IMAGE_BASE_TAG for SHA-pin.
TAG="${AI_IMAGE_BASE_TAG:-${PRESET}}"

LOCAL_TAG="ai-base:${PRESET}"
REMOTE_REF="${REGISTRY}:${TAG}"
MARKER_DIR="${HOME}/.ai-sandbox"
MARKER_FILE="${MARKER_DIR}/.ai-base-from-registry-acked"

log() {
  printf '[ensure-ai-base] %s\n' "$*" >&2
}

warn_gh() {
  printf '::warning::%s\n' "$*" >&2
}

err() {
  printf '❌ [ensure-ai-base] %s\n' "$*" >&2
}

# ---- First-run notice ------------------------------------------------------

maybe_first_run_notice() {
  if [[ -f "$MARKER_FILE" ]]; then
    return 0
  fi
  cat >&2 <<EOF
ℹ️  [ensure-ai-base] First run with registry-based ai-base.

    When BASE_IMAGE_MODE=registry (and the local ai-base:<preset> tag is missing),
    this helper will pull ${REMOTE_REF} from ${REGISTRY} instead of building locally.

    Your existing local ai-base:latest is preserved by BASE_IMAGE_MODE=local
    (the default for contributors iterating on lib/install-base.sh).

    To silence this notice permanently, the marker file has been written to:
      ${MARKER_FILE}

EOF
  if mkdir -p "$MARKER_DIR" 2>/dev/null && touch "$MARKER_FILE" 2>/dev/null; then
    : # marker created successfully; subsequent runs will skip the notice
  else
    # independent-review finding L1: surface marker-creation failure so users can clean up manually
    log "⚠️  Could not write marker at ${MARKER_FILE}; this notice will repeat on every registry-mode invocation. To silence permanently, run: mkdir -p '${MARKER_DIR}' && touch '${MARKER_FILE}'"
  fi
}

# ---- Mode: local -----------------------------------------------------------

ensure_local() {
  if docker image inspect "$LOCAL_TAG" >/dev/null 2>&1; then
    log "Using local ${LOCAL_TAG} (BASE_IMAGE_MODE=local)"
    return 0
  fi
  err "Local image '${LOCAL_TAG}' not found."
  err "Build it with: bash lib/install-base.sh"
  err "Or switch to registry mode: BASE_IMAGE_MODE=registry bash lib/install-<tool>.sh"
  return 1
}

# ---- Mode: registry -------------------------------------------------------

ensure_registry() {
  if docker image inspect "$LOCAL_TAG" >/dev/null 2>&1; then
    log "Using local ${LOCAL_TAG} (BASE_IMAGE_MODE=registry, local already present)"
    return 0
  fi

  maybe_first_run_notice

  log "Pulling ${REMOTE_REF} ..."
  if docker pull "$REMOTE_REF"; then
    # Compute the pulled image's digest for the success log line.
    local digest
    digest="$(docker image inspect --format '{{.Id}}' "$REMOTE_REF" 2>/dev/null || echo 'unknown')"
    log "Pulled ${REMOTE_REF} (${digest})"
    # Re-tag as the canonical local tag so tool Dockerfiles that say
    # 'FROM ai-base:<preset>' resolve to this image.
    if [[ "$LOCAL_TAG" != "$REMOTE_REF" ]]; then
      docker tag "$REMOTE_REF" "$LOCAL_TAG" >/dev/null
      log "Tagged ${LOCAL_TAG}"
    fi
    return 0
  fi

  # Pull failed.
  if [[ "$ALLOW_LOCAL_BUILD" == "1" ]]; then
    warn_gh "docker pull ${REMOTE_REF} failed; falling back to local build (BASE_IMAGE_ALLOW_LOCAL_BUILD=1)"
    log "Running: bash lib/install-base.sh"
    if bash "$(dirname "$0")/install-base.sh"; then
      log "Local build succeeded; using ai-base:latest"
      return 0
    fi
    err "Local build also failed. Network may be down AND toolchain missing."
    err "To opt out of fallback: BASE_IMAGE_ALLOW_LOCAL_BUILD=0 bash lib/install-<tool>.sh"
    return 1
  fi

  err "docker pull ${REMOTE_REF} failed and BASE_IMAGE_ALLOW_LOCAL_BUILD=0."
  err "Verify network connectivity, or set BASE_IMAGE_ALLOW_LOCAL_BUILD=1 to fall back to local build."
  err "Or pin to a known-good image: AI_IMAGE_BASE_TAG=base-sha-<old-sha> bash lib/install-<tool>.sh"
  return 1
}

# ---- Dispatch --------------------------------------------------------------

case "$MODE" in
  local)    ensure_local    ;;
  registry) ensure_registry ;;
  *)
    err "Unknown BASE_IMAGE_MODE='${MODE}' (expected 'local' or 'registry')"
    exit 1
    ;;
esac
