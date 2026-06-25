#!/bin/bash
set -e
apt-get update -y
apt-get install -y docker.io curl
systemctl enable docker
systemctl start docker

# Install Docker Compose as both a v2 CLI plugin and a legacy docker-compose binary.
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
