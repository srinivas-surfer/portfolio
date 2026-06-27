#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Deployment"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

log() {
  printf '[%s] %s\n' "$1" "$2"
}

finish() {
  local status="$1"
  local end_time
  end_time=$(date +%s)
  log "$status" "$STAGE finished in $((end_time - START_TIME))s"
}

fail() {
  log "ERROR" "$1"
  finish "FAILED"
  exit 1
}

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "Required environment variable is missing: $name"
}

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

log "INFO" "Deploying only compose service: $COMPOSE_SERVICE"
compose up -d --no-build "$COMPOSE_SERVICE"

docker_logout
trap - EXIT

log "SUCCESS" "Deployment completed for $SERVICE_NAME using $IMAGE_REF."
finish "SUCCESS"
