#!/usr/bin/env bash

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
    return
  fi

  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
    return
  fi

  return 127
}

compose_available() {
  docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1
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

Amazon Linux install option:
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
  sudo usermod -aG docker ec2-user
  newgrp docker

Restart the GitHub runner after changing Docker group membership.
EOF
}
