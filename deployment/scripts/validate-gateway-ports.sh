#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Gateway Port Validation"
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

trap 'fail "Unexpected failure at line $LINENO."' ERR

is_allowed_owner() {
  local owner="$1"
  local allowed
  local -a allowed_owners

  IFS=',' read -r -a allowed_owners <<< "${ALLOWED_PORT_OWNER_CONTAINERS:-npm}"
  for allowed in "${allowed_owners[@]}"; do
    allowed="${allowed//[[:space:]]/}"
    [[ "$owner" == "$allowed" ]] && return 0
  done

  return 1
}

container_host_ports() {
  local container="$1"

  docker inspect "$container" --format '{{range $containerPort, $bindings := .NetworkSettings.Ports}}{{if $bindings}}{{range $binding := $bindings}}{{println $binding.HostPort}}{{end}}{{end}}{{end}}'
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

log "INFO" "START $STAGE"

ensure_docker_stack || fail "Docker/Compose bootstrap failed."

IFS=',' read -r -a ports <<< "${GATEWAY_PORTS:-80,81,443}"

for port in "${ports[@]}"; do
  port="${port//[[:space:]]/}"
  [[ -n "$port" ]] || continue

  owners=()
  while IFS= read -r container; do
    [[ -n "$container" ]] || continue
    while IFS= read -r host_port; do
      [[ "$host_port" == "$port" ]] && owners+=("$container")
    done < <(container_host_ports "$container")
  done < <(docker ps --format '{{.Names}}')

  if (( ${#owners[@]} > 0 )); then
    for owner in "${owners[@]}"; do
      if ! is_allowed_owner "$owner"; then
        fail "Host port $port is already owned by unexpected container: $owner"
      fi
    done

    log "INFO" "Host port $port is already owned by allowed container(s): ${owners[*]}"
    continue
  fi

  if host_port_has_listener "$port"; then
    fail "Host port $port is already used by a non-Docker or unknown process."
  fi

  log "INFO" "Host port $port is available."
done

log "SUCCESS" "Gateway ports are available or already owned by the gateway."
finish "SUCCESS"
