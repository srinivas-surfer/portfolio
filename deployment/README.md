# Deployment Guide

This directory contains the Phase 1 CI/CD pilot for `portfolio_service`.

The pilot proves the production deployment pattern for one low-risk service before the same model is expanded to the rest of the platform.

## Current Scope

Implemented in Phase 1:

- PR code validation workflow
- Portfolio service build workflow
- Build approval gate
- Docker Hub login, push, and logout
- Docker Hub image validation
- Deploy approval gate
- Docker Hub login, pull, and logout
- Deployment of only `portfolio_service` without starting dependencies
- Application validation
- Local N-1 cleanup

Not implemented yet:

- Blog, projects, experience, contact, gateway, or master deployment workflows
- Docker Hub remote tag cleanup
- Rollback automation script
- Portainer, Prometheus, or cAdvisor

## Required GitHub Secrets

Configure these secrets in the repository or organization:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
DOCKERHUB_NAMESPACE
```

Use a Docker Hub access token, not an account password.

## GitHub Environments

Create these protected environments:

```text
build-approval
production-deploy
```

`build-approval` gates image creation and Docker Hub push.

`production-deploy` gates the service restart and production deployment.

## EC2 Runner Prerequisites

The self-hosted runner must run on the EC2 host that deploys the Docker Compose stack.

Required tools:

```text
git
docker
docker compose
bash
```

Amazon Linux setup:

```bash
sudo yum update -y
sudo yum install -y docker git
sudo systemctl enable docker
sudo systemctl start docker
```

The pipeline must be able to run Docker either directly or through passwordless sudo. It will not modify Linux groups and will not restart the GitHub runner.

When passwordless sudo is required for Docker, the deployment scripts preserve only Compose image interpolation values such as `DOCKERHUB_NAMESPACE` and `*_IMAGE_TAG`. Docker Hub credentials are not forwarded into the sudo environment.

Install Docker Compose V2 manually if `yum install docker-compose-plugin` is not available:

```bash
ARCH=$(uname -m)

if [ "$ARCH" = "x86_64" ]; then
  COMPOSE_ARCH="x86_64"
elif [ "$ARCH" = "aarch64" ]; then
  COMPOSE_ARCH="aarch64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -fSL \
  "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${COMPOSE_ARCH}" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
docker compose version
```

Verify runner access without restarting the runner:

```bash
docker ps || sudo -n docker ps
docker compose version || sudo -n docker compose version
```

## Portfolio Runtime Image

`portfolio_service` uses an immutable image tag supplied at deploy time:

```text
${DOCKERHUB_NAMESPACE}/portfolio:${PORTFOLIO_IMAGE_TAG}
```

Local default:

```text
local/portfolio:latest
```

Pipeline deployment:

```text
<dockerhub-namespace>/portfolio:<git-sha>
```

`portfolio_service` is intentionally deployable without `contact_service`. The compose deployment uses `--no-deps`, and the portfolio Nginx contact proxy resolves `contact_service` only when `/api/contact` is requested.

`contact_service` still requires real SMTP values for production use, but `contact/.env` is optional at compose render time so portfolio-only deployments are not blocked when the contact service is not part of the current release.

## Script Contract

GitHub Actions orchestrates only. Deployment logic lives in:

```text
deployment/scripts/
```

Every script prints:

- START
- SUCCESS or FAILED
- execution duration
- standardized log levels

## Pilot Service Inputs

The portfolio workflow passes:

```text
SERVICE_NAME=portfolio
SERVICE_PATH=portfolio
COMPOSE_SERVICE=portfolio_service
CONTAINER_NAME=portfolio_service
IMAGE_NAME=portfolio
IMAGE_TAG_ENV_VAR=PORTFOLIO_IMAGE_TAG
HEALTH_CHECK_MODE=container-exec
HEALTH_URL=http://127.0.0.1/
```
