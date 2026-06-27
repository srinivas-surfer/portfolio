# Deployment Guide

This directory contains the CI/CD scripts for the application platform.

The current implementation covers the first production services: `portfolio_service`, the gateway services `db` and `npm`, and `contact_service`.

## Current Scope

Implemented:

- PR code validation workflow
- Portfolio service build and deploy workflow
- Gateway deploy workflow for Nginx Proxy Manager and its database
- Contact service build and deploy workflow
- Build approval gate
- Docker Hub login, push, and logout
- Docker Hub image validation
- Deploy approval gate
- Docker Hub login, pull, and logout
- Deployment of only the targeted service or gateway services
- Gateway host port conflict validation for `80`, `81`, and `443`
- Contact runtime environment rendering from GitHub Secrets
- Application validation
- Local N-1 cleanup

Not implemented yet:

- Blog, projects, experience, or master deployment workflows
- Docker Hub remote tag cleanup
- Rollback automation script
- Portainer, Prometheus, or cAdvisor

## Required GitHub Secrets

Configure these secrets in the repository or organization:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
DOCKERHUB_NAMESPACE
NPM_DB_PASSWORD
NPM_DB_ROOT_PASSWORD
SMTP_HOST
SMTP_PORT
SMTP_SECURE
SMTP_USER
SMTP_PASS
SES_FROM_EMAIL
SES_TO_EMAIL
CORS_ORIGIN
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

## Contact Runtime Image

`contact_service` uses an immutable image tag supplied at deploy time:

```text
${DOCKERHUB_NAMESPACE}/contact:${CONTACT_IMAGE_TAG}
```

The contact workflow renders `contact/.env` on the EC2 runner from GitHub Secrets before deployment. The generated file is ignored by Git and should never be committed.

Required contact runtime values:

```text
SMTP_HOST
SMTP_PORT
SMTP_SECURE
SMTP_USER
SMTP_PASS
SES_FROM_EMAIL
SES_TO_EMAIL
CORS_ORIGIN
PORT=3000
NODE_ENV=production
```

## Gateway Deployment

The gateway workflow deploys only:

```text
db
npm
```

Before deployment it validates host port ownership for:

```text
80
81
443
```

The ports may be free or already owned by the `npm` container. If any other container or host process owns one of those ports, the pipeline fails before deployment.

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

The contact workflow uses the same service pipeline contract with:

```text
SERVICE_NAME=contact
SERVICE_PATH=contact
COMPOSE_SERVICE=contact_service
CONTAINER_NAME=contact_service
IMAGE_NAME=contact
IMAGE_TAG_ENV_VAR=CONTACT_IMAGE_TAG
HEALTH_CHECK_MODE=container-exec
HEALTH_URL=http://127.0.0.1:3000/health
```
