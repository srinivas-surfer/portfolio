#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Gateway Validation"
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

container_running() {
  local container="$1"
  local running

  running=$(docker inspect "$container" --format '{{.State.Running}}' 2>/dev/null || true)
  [[ "$running" == "true" ]]
}

wait_for_container() {
  local container="$1"
  local attempts="${GATEWAY_VALIDATE_ATTEMPTS:-30}"
  local sleep_seconds="${GATEWAY_VALIDATE_SLEEP_SECONDS:-5}"
  local attempt

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if container_running "$container"; then
      log "INFO" "Container is running: $container"
      return 0
    fi

    log "INFO" "Waiting for container $container ($attempt/$attempts)."
    sleep "$sleep_seconds"
  done

  return 1
}

http_get() {
  local url="$1"

  if command -v curl >/dev/null 2>&1; then
    curl -fsS "$url" >/tmp/gateway-health-response.out
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO /tmp/gateway-health-response.out "$url"
    return
  fi

  return 127
}

wait_for_http() {
  local url="$1"
  local attempts="${GATEWAY_VALIDATE_ATTEMPTS:-30}"
  local sleep_seconds="${GATEWAY_VALIDATE_SLEEP_SECONDS:-5}"
  local attempt

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if http_get "$url"; then
      log "INFO" "HTTP validation passed: $url"
      return 0
    fi

    log "INFO" "Waiting for HTTP endpoint $url ($attempt/$attempts)."
    sleep "$sleep_seconds"
  done

  return 1
}

trap 'fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

ensure_docker_stack || fail "Docker/Compose bootstrap failed."

wait_for_container db || fail "Gateway database container is not running: db"
wait_for_container npm || fail "Nginx Proxy Manager container is not running: npm"

log "INFO" "Recent db logs:"
docker logs --tail="${LOG_TAIL_LINES:-50}" db || true

log "INFO" "Recent npm logs:"
docker logs --tail="${LOG_TAIL_LINES:-50}" npm || true

IFS=',' read -r -a ports <<< "${GATEWAY_PORTS:-80,81,443}"
for port in "${ports[@]}"; do
  port="${port//[[:space:]]/}"
  [[ -n "$port" ]] || continue

  if ! docker port npm "${port}/tcp" >/dev/null 2>&1; then
    fail "Nginx Proxy Manager is not publishing host port $port."
  fi

  log "INFO" "Nginx Proxy Manager publishes port $port: $(docker port npm "${port}/tcp")"
done

wait_for_http "${NPM_ADMIN_URL:-http://127.0.0.1:81}" || fail "Nginx Proxy Manager admin endpoint is not responding."

mkdir -p deployment/releases
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
workflow_run_id="${GITHUB_RUN_ID:-local}"
db_image=$(docker inspect db --format '{{.Config.Image}}')
npm_image=$(docker inspect npm --format '{{.Config.Image}}')

printf '%s|gateway|db,npm|db=%s,npm=%s|%s|success\n' \
  "$timestamp" \
  "$db_image" \
  "$npm_image" \
  "$workflow_run_id" >> deployment/releases/gateway.history

log "SUCCESS" "Gateway validation passed."
finish "SUCCESS"
