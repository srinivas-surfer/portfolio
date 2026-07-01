# Deployment Guide

This directory contains the CI/CD scripts for the application platform.

The current implementation covers the production application services and a manual full-platform master deployment.

## Current Scope

Implemented:

- PR code validation workflow
- Portfolio service build and deploy workflow
- Blog service build and deploy workflow
- Projects service build and deploy workflow
- Experience service build and deploy workflow
- Contact service build and deploy workflow
- Manual master platform workflow
- Manual service rollback workflow
- Manual HTML platform report workflow
- Manual-only service deployment after merge to `main`
- Build approval gate
- Docker Hub login, push, and logout
- Docker Hub image validation
- Deploy approval gate
- Docker Hub login, pull, and logout
- Deployment of only the targeted service
- Legacy Nginx Proxy Manager decommission before portfolio binds host port `80`
- Contact runtime environment rendering from GitHub Secrets
- Application validation
- Local N-1 cleanup
- Persistent local release history under `/home/ec2-user/portfolio-deployment/releases`

Not implemented yet:

- Docker Hub remote tag cleanup
- Monitoring stack: Portainer, Prometheus, Node Exporter, cAdvisor, Dozzle, and Grafana Cloud remote write

## Required GitHub Secrets

Configure these secrets in the repository or organization:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
DOCKERHUB_NAMESPACE
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

Optional secret for the scheduled HTML report:

```text
REPORT_TO_EMAIL
```

If `REPORT_TO_EMAIL` is not configured, the report email is sent to the `SES_TO_EMAIL` value already available inside `contact_service`.

## GitHub Environments

Create these protected environments:

```text
build-approval
production-deploy
```

`build-approval` gates image creation and Docker Hub push.

`production-deploy` gates the service restart and production deployment.

## Trigger Model

Pull requests to `main` run code validation automatically.

Deployment workflows are manual-only:

```text
portfolio.yml
blog.yml
projects.yml
experience.yml
contact.yml
master.yml
rollback.yml
report.yml
```

After a PR is approved and merged to `main`, start the required service workflow or the master workflow from the GitHub Actions UI.

Use `rollback.yml` only when a deployed service must be returned to a previous image tag.

Use `report.yml` to generate a downloadable HTML health and page-view report without changing runtime state.

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

On small EC2 instances, the service workflows set `ALLOW_SWAP_MEMORY=true`, so pre-validation counts free swap together with available RAM. This is intended for the current single-instance deployment where a 1 GB swap file is configured.

The service workflows set:

```text
DEPLOYMENT_STATE_DIR=/home/ec2-user/portfolio-deployment/releases
COMPOSE_NETWORK_NAME=app_default
```

This keeps release history outside the GitHub checkout workspace so N-1 cleanup can preserve the current and previous successful local image tags across workflow runs.

The Compose network is intentionally external:

```text
app_default
```

`deploy-service.sh` creates it when missing. Compose then attaches the targeted service to that existing network instead of trying to recreate or relabel it, which avoids stale network label failures during independent service deployments.

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

## Runtime Images

`portfolio_service` uses an immutable image tag supplied at deploy time:

```text
${DOCKERHUB_NAMESPACE}/portfolio:${PORTFOLIO_IMAGE_TAG}
```

The remaining app services use the same model:

```text
${DOCKERHUB_NAMESPACE}/blog:${BLOG_IMAGE_TAG}
${DOCKERHUB_NAMESPACE}/projects:${PROJECTS_IMAGE_TAG}
${DOCKERHUB_NAMESPACE}/experience:${EXPERIENCE_IMAGE_TAG}
${DOCKERHUB_NAMESPACE}/contact:${CONTACT_IMAGE_TAG}
```

Local default:

```text
local/<service>:latest
```

Pipeline deployment:

```text
<dockerhub-namespace>/portfolio:<git-sha>
```

Each service is intentionally deployable without restarting unrelated services. The compose deployment uses `--no-deps`. The portfolio Nginx route proxy resolves internal services only when their paths are requested.

`contact_service` still requires real SMTP values for production use, but `contact/.env` is optional at compose render time so portfolio-only deployments are not blocked when the contact service is not part of the current release.

`portfolio_service` publishes EC2 host port `80` and acts as the CloudFront origin. During portfolio deployment, the pipeline stops and removes legacy `npm` and `db` containers when `DECOMMISSION_LEGACY_GATEWAY=true`, leaving their Docker volumes intact.

Portfolio path routing:

```text
/            -> portfolio_service
/blog/       -> blog_service
/projects/   -> projects_service
/experience/ -> experience_service
/api/contact -> contact_service
```

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

## Rollback

The rollback workflow is manual and protected by the `production-deploy` environment.

Inputs:

```text
service
image_tag
confirm=ROLLBACK
```

If `image_tag` is empty, the rollback script reads the selected service history from:

```text
/home/ec2-user/portfolio-deployment/releases/<service>.history
```

and selects the previous successful image tag. The rollback then pulls the image from Docker Hub, deploys only the selected service, validates it, and records the successful rollback as the new current release.

## HTML Report

The report workflow is manual and scheduled. It is read-only. It generates an HTML artifact and emails a readable HTML report body through the existing `contact_service` SES SMTP runtime.

The scheduled run uses:

```text
https://portfolio.srinivaspitchubabu.click
24h Docker log window
```

Manual runs include a `send_email` input. Keep `yes` to send the email, or clear the value to generate only the HTML artifact.

The public domain validates the full user path through Route 53 and CloudFront. Use `http://127.0.0.1` only for manual EC2-origin troubleshooting.

The report includes:

```text
Docker and Compose status
EC2 disk and memory summary
platform health score and server status
infrastructure health metrics
public DNS and TLS certificate checks
container health and image status
Docker resource usage and restart counts
hosted route health checks
approximate page-view counts from portfolio_service logs
container log alert counts
sanitized ongoing log alert details with detected error codes
```

Detailed report field definitions and troubleshooting steps are documented in:

```text
deployment/REPORTS.md
```

The email step executes inside the running `contact_service` container, so it reuses the same Node.js, Nodemailer, and SES SMTP environment that the contact form uses. The EC2 runner does not need native SMTP support in `curl`.

The report is uploaded as a GitHub Actions artifact named `portfolio-platform-report`. It should not be published as a public page because it contains operational details.

## CloudFront And Route 53

The public gateway is AWS-managed:

```text
Route 53 -> CloudFront -> EC2 origin port 80 -> portfolio_service
```

CloudFront should use an ACM certificate in `us-east-1` for:

```text
portfolio.srinivaspitchubabu.click
```

Use a separate origin DNS record, such as `origin.srinivaspitchubabu.click`, or the EC2 public DNS as the CloudFront origin. Do not use the same hostname for both the CloudFront viewer domain and the CloudFront origin.

Configure a separate CloudFront behavior for:

```text
/api/contact*
```

with all methods allowed and caching disabled.

The normal default CloudFront behavior can serve:

```text
/
/blog/*
/projects/*
/experience/*
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

## Service Inputs

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

The static service workflows use the same contract:

```text
SERVICE_NAME=blog|projects|experience
SERVICE_PATH=blog|projects|experience
COMPOSE_SERVICE=<service>_service
CONTAINER_NAME=<service>_service
IMAGE_NAME=blog|projects|experience
IMAGE_TAG_ENV_VAR=BLOG_IMAGE_TAG|PROJECTS_IMAGE_TAG|EXPERIENCE_IMAGE_TAG
HEALTH_CHECK_MODE=container-exec
HEALTH_URL=http://127.0.0.1/
```

## Master Pipeline

The master workflow is manual and deploys the complete application platform.

It runs:

```text
code validation
platform pre-validation
build all images
deploy all services
smoke tests
deployment summary
```

Builds and deployments run sequentially to avoid memory pressure on the single EC2 runner.

## Frontend Responsive Changes

Responsive UI updates are deployed through the affected service workflows:

```text
portfolio.yml
blog.yml
projects.yml
experience.yml
```

Use the master workflow when all frontend services should be rolled out together. After deployment, invalidate CloudFront paths when cached CSS or HTML needs to refresh quickly:

```text
/
/contact.html
/style.css
/blog/*
/projects/*
/experience/*
```
