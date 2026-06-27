# Recovery Guide

This guide covers recovery for the implemented platform pipelines: portfolio, gateway, and contact.

## Build Fails

Check:

```text
Docker daemon availability
Docker Hub credentials
portfolio/Dockerfile
contact/Dockerfile
Docker Hub namespace
runner disk and memory
```

No deployment occurs if build fails.

## Image Validation Fails

Check:

```text
Docker Hub push completed
image tag exists
image can be pulled
temporary startup logs
```

Do not approve deployment until image validation passes.

## Deploy Fails

Check:

```bash
docker compose ps portfolio_service
docker compose logs --tail=80 portfolio_service
docker image ls "<dockerhub-namespace>/portfolio"
```

For contact:

```bash
docker compose ps contact_service
docker compose logs --tail=80 contact_service
docker image ls "<dockerhub-namespace>/contact"
```

The app deploy script targets only:

```text
portfolio_service or contact_service
```

Unrelated services should remain running.

## Application Validation Fails

Check:

```bash
docker logs --tail=80 portfolio_service
docker exec portfolio_service wget -qO- http://127.0.0.1/
```

If the current image fails validation, use the rollback guide to redeploy the previous SHA.

For contact, also check that `contact/.env` exists on the EC2 runner and was generated from GitHub Secrets:

```bash
ls -l contact/.env
docker exec contact_service wget -qO- http://127.0.0.1:3000/health
```

## Gateway Deploy Fails

Check port ownership first:

```bash
docker ps
sudo ss -ltnp | grep -E ':80|:81|:443' || true
```

Allowed owner:

```text
npm
```

Unexpected owners such as host `nginx`, host `apache`, or another container must be stopped or moved before rerunning the gateway workflow.

Check gateway logs:

```bash
docker compose ps db npm
docker compose logs --tail=80 db
docker compose logs --tail=80 npm
```

If NPM cannot connect to MariaDB, verify `NPM_DB_PASSWORD` and `NPM_DB_ROOT_PASSWORD`. Existing `npm_db` volumes keep their original database credentials.

## Docker Hub Authentication Fails

Check GitHub Secrets:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
DOCKERHUB_NAMESPACE
```

Use a Docker Hub access token. Do not use a Docker Hub account password.

## Contact SMTP Fails

If `/health` passes but sending mail fails, check GitHub Secrets:

```text
SMTP_HOST
SMTP_PORT
SMTP_SECURE
SMTP_USER
SMTP_PASS
SES_FROM_EMAIL
SES_TO_EMAIL
CORS_ORIGIN
```

For the current SES SMTP setup, outbound TCP `587` must be allowed from EC2.

## Docker Compose Is Missing

If pre-validation fails with:

```text
Docker Compose is not available
```

verify on the EC2 runner:

```bash
docker --version
docker compose version
docker ps
```

On Amazon Linux, install Docker Compose V2 manually:

```bash
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then COMPOSE_ARCH="x86_64"; elif [ "$ARCH" = "aarch64" ]; then COMPOSE_ARCH="aarch64"; else echo "Unsupported architecture: $ARCH"; exit 1; fi
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -fSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${COMPOSE_ARCH}" -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
docker compose version
```

Do not restart or modify the GitHub runner from the pipeline. If direct Docker access is not available, configure passwordless sudo outside the pipeline or run the runner under a user that already has Docker access.
