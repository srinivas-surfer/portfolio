#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Application Validation"
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

trap 'fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

for var in SERVICE_NAME COMPOSE_SERVICE IMAGE_NAME IMAGE_TAG DOCKERHUB_NAMESPACE; do
  require_env "$var"
done

ensure_docker_stack || fail "Docker/Compose bootstrap failed."

CONTAINER_NAME="${CONTAINER_NAME:-$COMPOSE_SERVICE}"
HEALTH_CHECK_MODE="${HEALTH_CHECK_MODE:-container-exec}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1/}"
IMAGE_REF="${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

container_id=$(docker ps -q -f "name=^/${CONTAINER_NAME}$")
[[ -n "$container_id" ]] || fail "Container is not running: $CONTAINER_NAME"

running_image=$(docker inspect "$CONTAINER_NAME" --format '{{.Config.Image}}')
log "INFO" "Container $CONTAINER_NAME is running with image $running_image."

if [[ "$running_image" != "$IMAGE_REF" ]]; then
  fail "Container image mismatch. Expected $IMAGE_REF but found $running_image."
fi

log "INFO" "Recent container logs for $CONTAINER_NAME:"
docker logs --tail="${LOG_TAIL_LINES:-50}" "$CONTAINER_NAME" || true

case "$HEALTH_CHECK_MODE" in
  container-exec)
    log "INFO" "Running container health check: $HEALTH_URL"
    docker exec "$CONTAINER_NAME" wget -qO- "$HEALTH_URL" >/tmp/service-health-response.out
    ;;
  host)
    command -v curl >/dev/null 2>&1 || fail "curl is required for host health checks."
    log "INFO" "Running host health check: $HEALTH_URL"
    curl -fsS "$HEALTH_URL" >/tmp/service-health-response.out
    ;;
  docker-network)
    log "INFO" "Running Docker network health check: $HEALTH_URL"
    docker run --rm --network "${DOCKER_NETWORK:-gateway_default}" curlimages/curl:latest -fsS "$HEALTH_URL" >/tmp/service-health-response.out
    ;;
  *)
    fail "Unsupported HEALTH_CHECK_MODE: $HEALTH_CHECK_MODE"
    ;;
esac

exposed_ports=$(docker inspect "$CONTAINER_NAME" --format '{{json .Config.ExposedPorts}}')
log "INFO" "Exposed ports: $exposed_ports"

mkdir -p deployment/releases
image_id=$(docker image inspect "$IMAGE_REF" --format '{{.Id}}')
image_digest=$(docker image inspect "$IMAGE_REF" --format '{{range .RepoDigests}}{{println .}}{{end}}' | head -n 1)
release_file="deployment/releases/${SERVICE_NAME}.history"
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
workflow_run_id="${GITHUB_RUN_ID:-local}"

printf '%s|%s|%s|%s|%s|%s|%s|%s|success\n' \
  "$timestamp" \
  "$SERVICE_NAME" \
  "$COMPOSE_SERVICE" \
  "$IMAGE_REF" \
  "$IMAGE_TAG" \
  "$image_id" \
  "$image_digest" \
  "$workflow_run_id" >> "$release_file"

log "SUCCESS" "Application validation passed for $SERVICE_NAME."
finish "SUCCESS"
