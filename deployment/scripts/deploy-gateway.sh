#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Gateway Deployment"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="${RUNTIME_DIR:-deployment/runtime}"
GATEWAY_ENV_FILE="${GATEWAY_ENV_FILE:-$RUNTIME_DIR/gateway.env}"

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

reject_multiline_secret() {
  local name="$1"
  local value="${!name:-}"

  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
    fail "Environment variable must be a single line: $name"
  fi
}

write_gateway_env_file() {
  mkdir -p "$RUNTIME_DIR"
  chmod 700 "$RUNTIME_DIR"

  reject_multiline_secret NPM_DB_PASSWORD
  reject_multiline_secret NPM_DB_ROOT_PASSWORD

  umask 077
  {
    printf 'NPM_DB_PASSWORD=%s\n' "$NPM_DB_PASSWORD"
    printf 'NPM_DB_ROOT_PASSWORD=%s\n' "$NPM_DB_ROOT_PASSWORD"
  } > "$GATEWAY_ENV_FILE"
}

trap 'docker_logout; fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

for var in DOCKERHUB_USERNAME DOCKERHUB_TOKEN NPM_DB_PASSWORD NPM_DB_ROOT_PASSWORD; do
  require_env "$var"
done

ensure_docker_stack || fail "Docker/Compose bootstrap failed."

"$SCRIPT_DIR/validate-gateway-ports.sh"
write_gateway_env_file

log "INFO" "Logging in to Docker Hub as $DOCKERHUB_USERNAME."
printf '%s' "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin >/dev/null
trap 'docker_logout' EXIT

log "INFO" "Pulling gateway images: db npm."
compose --env-file "$GATEWAY_ENV_FILE" pull db npm

log "INFO" "Deploying gateway database service: db"
compose --env-file "$GATEWAY_ENV_FILE" up -d --no-build --no-deps db

log "INFO" "Deploying gateway proxy service: npm"
compose --env-file "$GATEWAY_ENV_FILE" up -d --no-build --no-deps npm

docker_logout
trap - EXIT

log "SUCCESS" "Gateway deployment completed for db and npm."
finish "SUCCESS"
