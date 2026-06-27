#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Docker Build"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

docker_logout() {
  docker logout >/dev/null 2>&1 || true
}

trap 'docker_logout; fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

for var in SERVICE_NAME SERVICE_PATH IMAGE_NAME DOCKERHUB_USERNAME DOCKERHUB_TOKEN DOCKERHUB_NAMESPACE; do
  require_env "$var"
done

ensure_docker_stack || fail "Docker/Compose bootstrap failed."

IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short=12 HEAD)}"
IMAGE_REPOSITORY="${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}"

log "INFO" "Logging in to Docker Hub as $DOCKERHUB_USERNAME."
printf '%s' "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin >/dev/null
trap 'docker_logout' EXIT

log "INFO" "Building $IMAGE_REPOSITORY for service $SERVICE_NAME."
docker build \
  --pull \
  --label "org.opencontainers.image.revision=$(git rev-parse HEAD)" \
  --label "org.opencontainers.image.source=${GITHUB_REPOSITORY:-local}" \
  -t "${IMAGE_REPOSITORY}:latest" \
  -t "${IMAGE_REPOSITORY}:${IMAGE_TAG}" \
  "$SERVICE_PATH"

log "INFO" "Pushing ${IMAGE_REPOSITORY}:latest."
docker push "${IMAGE_REPOSITORY}:latest"

log "INFO" "Pushing ${IMAGE_REPOSITORY}:${IMAGE_TAG}."
docker push "${IMAGE_REPOSITORY}:${IMAGE_TAG}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf 'image_tag=%s\n' "$IMAGE_TAG"
    printf 'image_repository=%s\n' "$IMAGE_REPOSITORY"
  } >> "$GITHUB_OUTPUT"
fi

docker_logout
trap - EXIT

log "SUCCESS" "Built and pushed $IMAGE_REPOSITORY:$IMAGE_TAG."
finish "SUCCESS"
