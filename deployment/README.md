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
- Deployment of only `portfolio_service`
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

