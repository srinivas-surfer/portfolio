#!/usr/bin/env bash

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

common_log() {
  if declare -F log >/dev/null 2>&1; then
    log "$1" "$2"
  else
    printf '[%s] %s\n' "$1" "$2"
  fi
}

sudo_available() {
  command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1
}

docker_cli_available() {
  command -v docker >/dev/null 2>&1
}

install_docker_amazon_linux() {
  if docker_cli_available; then
    return
  fi

  sudo_available || return 1

  common_log "INFO" "Docker is missing. Installing Docker with the available Amazon Linux package manager."
  if command -v yum >/dev/null 2>&1; then
    sudo -n yum install -y docker
  elif command -v dnf >/dev/null 2>&1; then
    sudo -n dnf install -y docker
  else
    return 1
  fi
}

start_docker_service() {
  docker_cli_available || return 1

  if command docker info >/dev/null 2>&1; then
    DOCKER_USE_SUDO="false"
    return
  fi

  if sudo_available && sudo -n docker info >/dev/null 2>&1; then
    DOCKER_USE_SUDO="true"
    return
  fi

  sudo_available || return 1

  if command -v systemctl >/dev/null 2>&1; then
    common_log "INFO" "Docker daemon is not reachable. Enabling and starting Docker service."
    sudo -n systemctl enable docker
    sudo -n systemctl start docker
  elif command -v service >/dev/null 2>&1; then
    common_log "INFO" "Docker daemon is not reachable. Starting Docker service."
    sudo -n service docker start
  else
    return 1
  fi
}

select_docker_mode() {
  docker_cli_available || return 1

  if command docker info >/dev/null 2>&1; then
    DOCKER_USE_SUDO="false"
    return 0
  fi

  if sudo_available && sudo -n docker info >/dev/null 2>&1; then
    DOCKER_USE_SUDO="true"
    common_log "WARN" "Using passwordless sudo for Docker commands because the runner user cannot access Docker directly."
    return 0
  fi

  return 1
}

docker() {
  if [[ "${DOCKER_USE_SUDO:-}" == "true" ]]; then
    sudo -n docker "$@"
  else
    command docker "$@"
  fi
}

install_compose_plugin() {
  compose_available && return 0
  docker_cli_available || return 1
  sudo_available || return 1

  local arch compose_arch
  arch=$(uname -m)
  case "$arch" in
    x86_64) compose_arch="x86_64" ;;
    aarch64 | arm64) compose_arch="aarch64" ;;
    *) return 1 ;;
  esac

  command -v curl >/dev/null 2>&1 || {
    common_log "INFO" "curl is missing. Installing curl."
    if command -v yum >/dev/null 2>&1; then
      sudo -n yum install -y curl
    elif command -v dnf >/dev/null 2>&1; then
      sudo -n dnf install -y curl
    else
      return 1
    fi
  }

  common_log "INFO" "Docker Compose is missing. Installing Docker Compose V2 plugin for $arch."
  sudo -n mkdir -p /usr/local/lib/docker/cli-plugins
  sudo -n curl -fSL \
    "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${compose_arch}" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  sudo -n chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
}

ensure_docker_stack() {
  install_docker_amazon_linux || {
    compose_install_hint
    return 1
  }

  start_docker_service || {
    compose_install_hint
    return 1
  }

  select_docker_mode || {
    compose_install_hint
    return 1
  }

  install_compose_plugin || {
    compose_install_hint
    return 1
  }

  compose_available || {
    compose_install_hint
    return 1
  }
}

compose() {
  local -a compose_env=()
  local env_assignment

  while IFS= read -r env_assignment; do
    compose_env+=("$env_assignment")
  done < <(compose_sudo_env)

  if [[ "${DOCKER_USE_SUDO:-}" == "true" ]]; then
    if sudo -n docker compose version >/dev/null 2>&1; then
      sudo -n env "${compose_env[@]}" docker compose "$@"
      return
    fi

    if command -v docker-compose >/dev/null 2>&1; then
      sudo -n env "${compose_env[@]}" docker-compose "$@"
      return
    fi

    return 127
  fi

  if command docker compose version >/dev/null 2>&1; then
    command docker compose "$@"
    return
  fi

  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
    return
  fi

  return 127
}

compose_sudo_env() {
  local name

  if [[ -n "${DOCKERHUB_NAMESPACE:-}" ]]; then
    printf '%s\n' "DOCKERHUB_NAMESPACE=$DOCKERHUB_NAMESPACE"
  fi

  while IFS= read -r name; do
    if [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*_IMAGE_TAG$ && -n "${!name:-}" ]]; then
      printf '%s\n' "$name=${!name}"
    fi
  done < <(compgen -v)
}

compose_available() {
  docker_cli_available && docker compose version >/dev/null 2>&1 && return 0
  command -v docker-compose >/dev/null 2>&1
}

compose_version() {
  if docker compose version >/dev/null 2>&1; then
    docker compose version
    return
  fi

  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose version
    return
  fi

  return 127
}

compose_install_hint() {
  cat <<'EOF'
Docker Compose is not available on this runner.

The pipeline is allowed to install/start Docker and install Docker Compose, but it will not modify or restart the GitHub runner.

Amazon Linux manual install option:
  sudo yum install -y docker
  sudo systemctl enable docker
  sudo systemctl start docker
  ARCH=$(uname -m)
  if [ "$ARCH" = "x86_64" ]; then COMPOSE_ARCH="x86_64"; elif [ "$ARCH" = "aarch64" ]; then COMPOSE_ARCH="aarch64"; else echo "Unsupported architecture: $ARCH"; exit 1; fi
  sudo mkdir -p /usr/local/lib/docker/cli-plugins
  sudo curl -fSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${COMPOSE_ARCH}" -o /usr/local/lib/docker/cli-plugins/docker-compose
  sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  docker compose version

If Docker permission is denied:
  configure passwordless sudo for Docker or run the GitHub runner as a user that already has Docker access.
EOF
}
