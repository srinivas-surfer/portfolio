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

for var in SERVICE_NAME SERVICE_PATH COMPOSE_SERVICE IMAGE_NAME DOCKERHUB_USERNAME DOCKERHUB_TOKEN DOCKERHUB_NAMESPACE; do
  require_env "$var"
done

IFS=',' read -r -a extra_required_env <<< "${REQUIRED_ENV_VARS:-}"
for var in "${extra_required_env[@]}"; do
  var="${var//[[:space:]]/}"
  [[ -z "$var" ]] && continue
  require_env "$var"
done

command -v git >/dev/null 2>&1 || fail "git is not installed."
command -v docker >/dev/null 2>&1 || fail "docker is not installed."
if ! compose_available; then
  compose_install_hint
  fail "Docker Compose is not available."
fi
log "INFO" "Compose check passed: $(compose_version | head -n 1)"
docker info >/dev/null 2>&1 || fail "Docker daemon is not reachable."

[[ -f docker-compose.yml ]] || fail "docker-compose.yml is missing."
[[ -d "$SERVICE_PATH" ]] || fail "Service path missing: $SERVICE_PATH"
[[ -f "$SERVICE_PATH/Dockerfile" ]] || fail "Service Dockerfile missing: $SERVICE_PATH/Dockerfile"

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
compose config --services | grep -Fx "$COMPOSE_SERVICE" >/dev/null || fail "Compose service not found: $COMPOSE_SERVICE"

cleanup_temp_env
trap - EXIT

log "SUCCESS" "Pre validation passed for $SERVICE_NAME."
finish "SUCCESS"
