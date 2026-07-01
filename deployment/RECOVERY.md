# Recovery Guide

This guide covers recovery for the implemented platform pipelines: portfolio, blog, projects, experience, contact, and the manual master workflow.

## Build Fails

Check:

```text
Docker daemon availability
Docker Hub credentials
portfolio/Dockerfile
blog/Dockerfile
projects/Dockerfile
experience/Dockerfile
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

For static services:

```bash
docker compose ps blog_service projects_service experience_service
docker compose logs --tail=80 blog_service
docker compose logs --tail=80 projects_service
docker compose logs --tail=80 experience_service
docker image ls "<dockerhub-namespace>/blog"
docker image ls "<dockerhub-namespace>/projects"
docker image ls "<dockerhub-namespace>/experience"
```

The app deploy script targets only:

```text
portfolio_service or contact_service
```

Unrelated services should remain running.

If deployment fails with a Docker Compose network label error for `app_default`, make sure the latest pipeline code is deployed. The Compose network is intentionally external, and `deploy-service.sh` creates it when missing instead of asking Compose to own or relabel it.

## Application Validation Fails

Check:

```bash
docker logs --tail=80 portfolio_service
docker exec portfolio_service wget -qO- http://127.0.0.1/
```

If the current image fails validation, use the rollback guide to redeploy the previous SHA.

The preferred recovery path is the manual `Service Rollback` workflow. Select the affected service, leave `image_tag` empty for automatic N-1 rollback, and set `confirm` to `ROLLBACK`.

For contact, also check that `contact/.env` exists on the EC2 runner and was generated from GitHub Secrets:

```bash
ls -l contact/.env
docker exec contact_service wget -qO- http://127.0.0.1:3000/health
```

For hosted path validation through portfolio:

```bash
curl -I http://127.0.0.1/
curl -I http://127.0.0.1/blog/
curl -I http://127.0.0.1/projects/
curl -I http://127.0.0.1/experience/
curl -i -X POST http://127.0.0.1/api/contact -H "Content-Type: application/json" -d '{}'
```

The empty contact payload should return `400 Bad Request`; this confirms routing without sending mail.

## Frontend Visual Regression

If a responsive page layout breaks after deployment, first confirm which service owns the changed page:

```text
/              -> portfolio_service
/contact.html  -> portfolio_service
/blog/         -> blog_service
/projects/     -> projects_service
/experience/   -> experience_service
```

Rollback only the affected service image unless the master workflow deployed all frontend services together.

## CloudFront Origin Deploy Fails

Check port ownership first:

```bash
docker ps
sudo ss -ltnp | grep ':80' || true
```

Expected owner after deployment:

```text
portfolio_service
```

Unexpected owners such as legacy `npm`, host `nginx`, host `apache`, or another container must be stopped or moved before rerunning the portfolio workflow.

The portfolio workflow runs:

```text
deployment/scripts/decommission-legacy-gateway.sh
```

with `DECOMMISSION_LEGACY_GATEWAY=true` before recreating `portfolio_service`.

Check origin health:

```bash
docker compose ps portfolio_service
docker compose logs --tail=80 portfolio_service
curl -I http://127.0.0.1
```

If CloudFront returns an error after the EC2 origin works, check the CloudFront origin domain, security group inbound rules, and the cache behavior for `/api/contact*`.

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

## Reporting

Use the manual `Platform HTML Report` workflow when you need a snapshot of runtime health before or after recovery.

The report includes:

```text
Docker and Compose status
host disk and memory summary
container state and health
current image names
hosted route checks
approximate page-view counts from portfolio_service logs
container log alert counts
```

Download the `portfolio-platform-report` artifact from the workflow run. Keep it internal because it contains operational details.
