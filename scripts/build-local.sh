#!/usr/bin/env bash
set -euo pipefail

TOOL="${1:-opencode}"
PRESET="${2:-base}"
PUSH="${PUSH:-false}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
REGISTRY="ghcr.io"
OWNER="nano-step"
IMAGE="${REGISTRY}/${OWNER}/ai-${TOOL}"

SHORT_SHA="$(git rev-parse --short HEAD)"
VERSION="$(node -p "require('./package.json').version")"

TAG_ROLLING="${IMAGE}:${PRESET}"
TAG_SHA="${IMAGE}:${PRESET}-sha-${SHORT_SHA}"
TAG_VERSION="${IMAGE}:${PRESET}-v${VERSION}"

PRESET_FILE="ci/presets/${PRESET}.env"
if [[ ! -f "$PRESET_FILE" ]]; then
  echo "❌ Preset file not found: $PRESET_FILE"
  exit 1
fi

FROM_IMAGE_PRESET=""
while IFS='=' read -r key value; do
  [[ "$key" =~ ^[[:space:]]*# ]] && continue
  [[ -z "$key" ]] && continue
  key="$(echo "$key" | tr -d '[:space:]')"
  value="$(echo "$value" | tr -d '[:space:]')"
  [[ -z "$key" || -z "$value" ]] && continue
  export "$key=$value"
  [[ "$key" == "FROM_IMAGE_PRESET" ]] && FROM_IMAGE_PRESET="$value"
done < "$PRESET_FILE"

echo "🔧 Building ai-${TOOL}:${PRESET} (${PLATFORMS})"
echo "   push=${PUSH}, short_sha=${SHORT_SHA}, version=${VERSION}"

BUILD_ARGS=()
if [[ "$PUSH" == "true" ]]; then
  BUILD_ARGS+=(--push)
else
  BUILD_ARGS+=(--load)
  if [[ "$PLATFORMS" == *","* ]]; then
    echo "⚠️  --load does not support multiple platforms. Switching to --push or use single platform."
    echo "   Set PUSH=true to push to registry, or PLATFORMS=linux/amd64 for local load."
    exit 1
  fi
fi

if [[ -z "$FROM_IMAGE_PRESET" ]]; then
  echo ""
  echo "📦 Step 1/2: Build ai-base"
  GENERATE_ONLY=1 bash lib/install-base.sh
  BASE_TAG="${IMAGE}:${PRESET}-base-${SHORT_SHA}"
  docker buildx build \
    --platform "${PLATFORMS}" \
    "${BUILD_ARGS[@]}" \
    --build-arg AGENT_UID=1001 \
    --tag "${BASE_TAG}" \
    dockerfiles/base
  echo "✅ ai-base → ${BASE_TAG}"
  BASE_IMAGE_REF="${BASE_TAG}"
else
  echo ""
  echo "📦 Step 1/2: Reusing published base (${FROM_IMAGE_PRESET})"
  BASE_IMAGE_REF="${IMAGE}:${FROM_IMAGE_PRESET}"
fi

echo ""
echo "🔨 Step 2/2: Build ai-${TOOL} (${PRESET})"
GENERATE_ONLY=1 bash "lib/install-${TOOL}.sh"
docker buildx build \
  --platform "${PLATFORMS}" \
  "${BUILD_ARGS[@]}" \
  --build-arg "BASE_IMAGE=${BASE_IMAGE_REF}" \
  --tag "${TAG_ROLLING}" \
  --tag "${TAG_SHA}" \
  --tag "${TAG_VERSION}" \
  "dockerfiles/${TOOL}"

echo ""
echo "✅ Done!"
echo "   ${TAG_ROLLING}"
echo "   ${TAG_SHA}"
echo "   ${TAG_VERSION}"
