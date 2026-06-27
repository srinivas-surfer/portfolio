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

