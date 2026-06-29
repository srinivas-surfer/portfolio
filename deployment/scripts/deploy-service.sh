#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Deployment"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

docker_logout() {
  docker logout >/dev/null 2>&1 || true
}

trap 'docker_logout; fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

for var in SERVICE_NAME COMPOSE_SERVICE IMAGE_NAME IMAGE_TAG IMAGE_TAG_ENV_VAR DOCKERHUB_USERNAME DOCKERHUB_TOKEN DOCKERHUB_NAMESPACE; do
  require_env "$var"
done

ensure_docker_stack || fail "Docker/Compose bootstrap failed."

IMAGE_REPOSITORY="${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}"
IMAGE_REF="${IMAGE_REPOSITORY}:${IMAGE_TAG}"

log "INFO" "Logging in to Docker Hub as $DOCKERHUB_USERNAME."
printf '%s' "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin >/dev/null
trap 'docker_logout' EXIT

log "INFO" "Pulling deployment image $IMAGE_REF."
docker pull "$IMAGE_REF"

export "${IMAGE_TAG_ENV_VAR}=${IMAGE_TAG}"
export DOCKERHUB_NAMESPACE

compose_network_name="${COMPOSE_NETWORK_NAME:-app_default}"
if docker network inspect "$compose_network_name" >/dev/null 2>&1; then
  log "INFO" "Compose network exists: $compose_network_name"
else
  log "INFO" "Creating external Compose network: $compose_network_name"
  docker network create "$compose_network_name" >/dev/null
fi

log "INFO" "Deploying only compose service: $COMPOSE_SERVICE"
compose up -d --no-build --no-deps "$COMPOSE_SERVICE"

docker_logout
trap - EXIT

log "SUCCESS" "Deployment completed for $SERVICE_NAME using $IMAGE_REF."
finish "SUCCESS"
