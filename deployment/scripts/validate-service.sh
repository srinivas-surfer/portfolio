#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Application Validation"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

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

health_max_retries="${HEALTH_CHECK_RETRIES:-5}"
health_retry_delay="${HEALTH_CHECK_RETRY_DELAY:-3}"
health_attempt=0
health_ok=false

while (( health_attempt < health_max_retries )); do
  health_attempt=$((health_attempt + 1))
  log "INFO" "Health check attempt $health_attempt/$health_max_retries ($HEALTH_CHECK_MODE): $HEALTH_URL"

  case "$HEALTH_CHECK_MODE" in
    container-exec)
      if docker exec "$CONTAINER_NAME" wget -qO- "$HEALTH_URL" >/tmp/service-health-response.out 2>/dev/null; then
        health_ok=true
      fi
      ;;
    host)
      command -v curl >/dev/null 2>&1 || fail "curl is required for host health checks."
      if curl -fsS "$HEALTH_URL" >/tmp/service-health-response.out 2>/dev/null; then
        health_ok=true
      fi
      ;;
    docker-network)
      if docker run --rm --network "${DOCKER_NETWORK:-app_default}" curlimages/curl:8.10.1 -fsS "$HEALTH_URL" >/tmp/service-health-response.out 2>/dev/null; then
        health_ok=true
      fi
      ;;
    *)
      fail "Unsupported HEALTH_CHECK_MODE: $HEALTH_CHECK_MODE"
      ;;
  esac

  if [[ "$health_ok" == "true" ]]; then
    break
  fi

  if (( health_attempt < health_max_retries )); then
    log "WARN" "Health check failed on attempt $health_attempt. Retrying in ${health_retry_delay}s..."
    sleep "$health_retry_delay"
  fi
done

if [[ "$health_ok" != "true" ]]; then
  log "INFO" "Recent container logs for $CONTAINER_NAME:"
  docker logs --tail="${LOG_TAIL_LINES:-50}" "$CONTAINER_NAME" || true
  fail "Health check failed after $health_max_retries attempts."
fi

log "INFO" "Health check passed on attempt $health_attempt."

exposed_ports=$(docker inspect "$CONTAINER_NAME" --format '{{json .Config.ExposedPorts}}')
log "INFO" "Exposed ports: $exposed_ports"

release_dir="${DEPLOYMENT_STATE_DIR:-deployment/releases}"
mkdir -p "$release_dir"
image_id=$(docker image inspect "$IMAGE_REF" --format '{{.Id}}')
image_digest=$(docker image inspect "$IMAGE_REF" --format '{{range .RepoDigests}}{{println .}}{{end}}' | head -n 1)
release_file="${release_dir}/${SERVICE_NAME}.history"
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
