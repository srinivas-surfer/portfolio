#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Legacy Gateway Decommission"
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

container_exists() {
  local container="$1"
  [[ -n "$(docker ps -aq -f "name=^/${container}$")" ]]
}

container_running() {
  local container="$1"
  [[ -n "$(docker ps -q -f "name=^/${container}$")" ]]
}

host_port_owned_by_container() {
  local port="$1"
  local container="$2"

  docker inspect "$container" --format '{{range $containerPort, $bindings := .NetworkSettings.Ports}}{{if $bindings}}{{range $binding := $bindings}}{{println $binding.HostPort}}{{end}}{{end}}{{end}}' 2>/dev/null | grep -Fx "$port" >/dev/null
}

host_port_has_listener() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Eq "(^|[:.])${port}$"
    return
  fi

  if command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | awk 'NR > 2 {print $4}' | grep -Eq "(^|[:.])${port}$"
    return
  fi

  log "WARN" "Neither ss nor netstat is available; host process port checks are limited."
  return 1
}

trap 'fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

if [[ "${DECOMMISSION_LEGACY_GATEWAY:-false}" != "true" ]]; then
  log "INFO" "Legacy gateway decommission is disabled; skipping."
  finish "SUCCESS"
  exit 0
fi

ensure_docker_stack || fail "Docker/Compose bootstrap failed."

IFS=',' read -r -a containers <<< "${LEGACY_GATEWAY_CONTAINERS:-npm,db}"
for container in "${containers[@]}"; do
  container="${container//[[:space:]]/}"
  [[ -n "$container" ]] || continue

  if ! container_exists "$container"; then
    log "INFO" "Legacy gateway container is not present: $container"
    continue
  fi

  if container_running "$container"; then
    log "INFO" "Stopping legacy gateway container: $container"
    docker stop "$container" >/dev/null
  fi

  log "INFO" "Removing legacy gateway container without removing volumes: $container"
  docker rm "$container" >/dev/null
done

if host_port_has_listener 80; then
  if container_exists portfolio_service && host_port_owned_by_container 80 portfolio_service; then
    log "INFO" "Host port 80 is already owned by portfolio_service."
  else
    fail "Host port 80 is still in use after legacy gateway decommission."
  fi
else
  log "INFO" "Host port 80 is available for portfolio_service."
fi

log "SUCCESS" "Legacy gateway decommission completed."
finish "SUCCESS"
