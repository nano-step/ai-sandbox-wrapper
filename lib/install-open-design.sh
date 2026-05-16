#!/usr/bin/env bash
set -e

dockerfile_snippet() {
  cat <<'SNIPPET'
# open-design is a service-type tool (long-running daemon)
# It uses its own upstream image, not ai-base
# This snippet is included for convention only; the base image builder
# does NOT inline open-design (it runs as a separate container)
SNIPPET
}

if [[ "${SNIPPET_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

TOOL="open-design"
OPEN_DESIGN_IMAGE="${OPEN_DESIGN_IMAGE:-docker.io/vanjayak/open-design:latest}"
OPEN_DESIGN_VERSION="${OPEN_DESIGN_VERSION:-latest}"

echo "Installing $TOOL (Open Design daemon — long-running HTTP service)..."
echo "  Upstream image: $OPEN_DESIGN_IMAGE"

mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Generate Dockerfile (idempotent — overwrites existing)
cat > "dockerfiles/$TOOL/Dockerfile" <<EOF
FROM $OPEN_DESIGN_IMAGE

# Force daemon to bind on all interfaces inside the container.
# Bearer token auth (OD_API_TOKEN env) protects the daemon.
ENV OD_BIND_HOST=0.0.0.0

# Document the port (publishing is controlled by ai-run --expose)
EXPOSE 7456

# Daemon entrypoint is provided by upstream image (do not override)
EOF

# Build image
echo "Building Docker image for $TOOL..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed (Open Design daemon)"
echo ""
echo "Features:"
echo "  ✓ Long-running HTTP daemon (port 7456 inside container)"
echo "  ✓ Bearer token auth (OD_API_TOKEN)"
echo "  ✓ Persistent state via named volume (ai-open-design-data)"
echo "  ✓ Internal-only by default (use --expose to publish to host)"
echo ""
echo "Usage:"
echo "  ai-run open-design init     # one-time: generate token, network, volume"
echo "  ai-run open-design start    # boot daemon"
echo "  ai-run open-design status   # check health"
