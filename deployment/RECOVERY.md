# Recovery Guide

This guide covers Phase 1 recovery for the `portfolio_service` CI/CD pilot.

## Build Fails

Check:

```text
Docker daemon availability
Docker Hub credentials
portfolio/Dockerfile
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

The deploy script targets only:

```text
portfolio_service
```

Unrelated services should remain running.

## Application Validation Fails

Check:

```bash
docker logs --tail=80 portfolio_service
docker exec portfolio_service wget -qO- http://127.0.0.1/
```

If the current image fails validation, use the rollback guide to redeploy the previous SHA.

## Docker Hub Authentication Fails

Check GitHub Secrets:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
DOCKERHUB_NAMESPACE
```

Use a Docker Hub access token. Do not use a Docker Hub account password.

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

Restart the GitHub runner after Docker or group membership changes.
