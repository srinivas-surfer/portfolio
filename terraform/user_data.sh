#!/bin/bash
set -e
apt-get update -y
apt-get install -y docker.io curl
systemctl enable docker
systemctl start docker
# docker compose plugin
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
