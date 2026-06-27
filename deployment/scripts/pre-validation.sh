#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Pre Validation"
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

for var in SERVICE_NAME COMPOSE_SERVICE; do
  require_env "$var"
done

if [[ "${REQUIRE_IMAGE_CONFIG:-true}" != "false" ]]; then
  for var in SERVICE_PATH IMAGE_NAME DOCKERHUB_USERNAME DOCKERHUB_TOKEN DOCKERHUB_NAMESPACE; do
    require_env "$var"
  done
fi

IFS=',' read -r -a extra_required_env <<< "${REQUIRED_ENV_VARS:-}"
for var in "${extra_required_env[@]}"; do
  var="${var//[[:space:]]/}"
  [[ -z "$var" ]] && continue
  require_env "$var"
done

command -v git >/dev/null 2>&1 || fail "git is not installed."
ensure_docker_stack || fail "Docker/Compose bootstrap failed."
log "INFO" "Docker check passed: $(docker --version)"
log "INFO" "Compose check passed: $(compose_version | head -n 1)"

[[ -f docker-compose.yml ]] || fail "docker-compose.yml is missing."

if [[ -n "${SERVICE_PATH:-}" ]]; then
  [[ -d "$SERVICE_PATH" ]] || fail "Service path missing: $SERVICE_PATH"
  if [[ "${REQUIRE_SERVICE_DOCKERFILE:-true}" != "false" ]]; then
    [[ -f "$SERVICE_PATH/Dockerfile" ]] || fail "Service Dockerfile missing: $SERVICE_PATH/Dockerfile"
  fi
fi

available_disk_mb=$(df -Pm . | awk 'NR==2 {print $4}')
min_disk_mb="${MIN_DISK_MB:-1024}"
if (( available_disk_mb < min_disk_mb )); then
  fail "Insufficient disk space: ${available_disk_mb}MB available, ${min_disk_mb}MB required."
fi
log "INFO" "Disk check passed: ${available_disk_mb}MB available."

min_memory_mb="${MIN_MEMORY_MB:-512}"
available_memory_mb="0"
if [[ -r /proc/meminfo ]]; then
  available_memory_mb=$(awk '/MemAvailable/ {print int($2 / 1024)}' /proc/meminfo)
elif command -v sysctl >/dev/null 2>&1; then
  available_memory_mb=$(sysctl -n hw.memsize 2>/dev/null | awk '{print int($1 / 1024 / 1024)}')
fi

if [[ "$available_memory_mb" != "0" ]]; then
  if (( available_memory_mb < min_memory_mb )); then
    fail "Insufficient memory: ${available_memory_mb}MB available, ${min_memory_mb}MB required."
  fi
  log "INFO" "Memory check passed: ${available_memory_mb}MB available."
else
  log "WARN" "Could not determine available memory."
fi

temp_contact_env="false"
if [[ ! -f contact/.env && -f contact/.env.example ]]; then
  cp contact/.env.example contact/.env
  temp_contact_env="true"
fi

cleanup_temp_env() {
  if [[ "$temp_contact_env" == "true" ]]; then
    rm -f contact/.env
  fi
}
trap 'cleanup_temp_env' EXIT

compose config >/tmp/portfolio-compose-config.out

IFS=',' read -r -a compose_services <<< "${REQUIRED_COMPOSE_SERVICES:-$COMPOSE_SERVICE}"
for service in "${compose_services[@]}"; do
  service="${service//[[:space:]]/}"
  [[ -z "$service" ]] && continue
  compose config --services | grep -Fx "$service" >/dev/null || fail "Compose service not found: $service"
done

cleanup_temp_env
trap - EXIT

log "SUCCESS" "Pre validation passed for $SERVICE_NAME."
finish "SUCCESS"
