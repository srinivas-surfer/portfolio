# Pipeline Documentation

## Governance Flow

```text
Developer branch
  -> Pull request to main
  -> PR code validation
  -> PR approval
  -> Merge to main
  -> Manual service or master workflow dispatch
  -> Service pre-validation
  -> Build approval
  -> Docker build, when the service owns an image
  -> Docker Hub push, when the service owns an image
  -> Image validation
  -> Deploy approval
  -> Docker Hub pull
  -> Deploy only the targeted service
  -> Application validation
  -> N-1 local cleanup
```

Rollback and reporting are separate manual operations. They do not run from pull requests or from merges to `main`.

## Workflows

### `pr-validation.yml`

Runs on pull requests targeting `main`.

Purpose:

- Validate repository structure
- Validate Docker Compose rendering when Docker is available
- Validate shell script syntax
- Detect committed `.env` files
- Validate `contact/package.json` when Node.js is available
- Validate Terraform formatting when Terraform is available

This workflow never deploys, restarts containers, or modifies production state.

### `portfolio.yml`

Runs only on manual `workflow_dispatch`.

Merging to `main` does not automatically build or deploy portfolio.

Jobs:

```text
pre-validation
build
deploy
```

The `build` job uses the `build-approval` environment.

The `deploy` job uses the `production-deploy` environment.

### `blog.yml`, `projects.yml`, `experience.yml`

Each static content service has its own workflow.

Runs on:

- manual `workflow_dispatch`

Merging to `main` does not automatically build or deploy static content services.

Jobs:

```text
pre-validation
build
deploy
```

Each workflow builds and pushes:

```text
<namespace>/<service>:latest
<namespace>/<service>:<git-sha>
```

Each deploy job targets only its matching Compose service with `--no-deps`:

```text
blog_service
projects_service
experience_service
```

The `build` job uses the `build-approval` environment.

The `deploy` job uses the `production-deploy` environment.

### `contact.yml`

Runs only on manual `workflow_dispatch`.

Merging to `main` does not automatically build or deploy contact.

Jobs:

```text
pre-validation
build
deploy
```

The contact workflow builds and pushes:

```text
<namespace>/contact:latest
<namespace>/contact:<git-sha>
```

Before deployment it renders `contact/.env` from GitHub Secrets, then deploys only:

```text
contact_service
```

The `build` job uses the `build-approval` environment.

The `deploy` job uses the `production-deploy` environment.

### `master.yml`

Runs manually through `workflow_dispatch`.

Purpose:

- validate the complete platform
- build all service images sequentially
- deploy all service containers sequentially
- run hosted path smoke tests
- publish a deployment summary

Execution order:

```text
validation
build portfolio
build blog
build projects
build experience
build contact
deploy portfolio
deploy blog
deploy projects
deploy experience
deploy contact
smoke tests
summary
```

The master workflow is intentionally sequential to reduce memory pressure on the single EC2 runner. It uses one `build-approval` gate for all builds and one `production-deploy` gate for all deployments.

## Docker Hub Authentication

Build and deploy stages login to Docker Hub with:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
```

Each script logs out before completion. The scripts must never print token values.

## Image Tags

The portfolio workflow pushes:

```text
<namespace>/portfolio:latest
<namespace>/portfolio:<git-sha>
```

The contact workflow pushes:

```text
<namespace>/contact:latest
<namespace>/contact:<git-sha>
```

The blog, projects, and experience workflows use the same tag model:

```text
<namespace>/blog:latest
<namespace>/blog:<git-sha>
<namespace>/projects:latest
<namespace>/projects:<git-sha>
<namespace>/experience:latest
<namespace>/experience:<git-sha>
```

Deployment uses the immutable Git SHA tag.

## Service Isolation

The portfolio workflow deploys only:

```text
portfolio_service
```

It must not restart `blog_service`, `projects_service`, `experience_service`, or `contact_service`.

The blog, projects, experience, and contact workflows follow the same isolation rule for their own services.

Deployment scripts use `docker compose up -d --no-build --no-deps <service>` so Compose recreates only the requested service. Portfolio no longer depends on `contact_service` at compose startup; contact remains a separately deployable service.

The portfolio workflow also runs a one-time legacy gateway decommission step so old `npm` and `db` containers do not block EC2 host port `80`. The active public gateway is AWS CloudFront, not a Docker service.

The master workflow is the exception to the single-service deployment rule because it is explicitly requested as a full-platform deployment. Even there, each service is deployed through the same targeted `--no-deps` command.

Frontend responsive changes should deploy only the services whose HTML, CSS, or JS changed. Use the master workflow only when a coordinated full frontend rollout is intended.

### `rollback.yml`

Runs manually through `workflow_dispatch`.

Purpose:

- roll back one selected service without building a new image
- use an explicit image tag when provided
- otherwise resolve the previous successful local release from N-1 history
- pull the rollback image from Docker Hub
- deploy only the selected Compose service with `--no-deps`
- validate the rolled back container and health endpoint
- run local cleanup after a successful rollback

Inputs:

```text
service    = portfolio, blog, projects, experience, or contact
image_tag  = optional Docker image tag
confirm    = must be ROLLBACK
```

The rollback job uses the `production-deploy` environment because it changes production runtime state.

For contact rollback, the workflow renders `contact/.env` from GitHub Secrets before recreating `contact_service`.

### `report.yml`

Runs manually through `workflow_dispatch` and daily through `schedule`.

The scheduled run executes at:

```text
14:30 UTC
20:00 IST
```

Scheduled runs use the public production domain:

```text
https://portfolio.srinivaspitchubabu.click
```

Manual runs include `send_email`. Keep it as `yes` to send the email, or leave it empty to upload only the HTML artifact.

Purpose:

- generate a downloadable HTML platform report
- email the HTML report body through the existing `contact_service` SES SMTP runtime
- calculate a platform health score and server status
- summarize Docker, Compose, disk, and memory status
- summarize infrastructure, public DNS, TLS certificate, and Docker resource usage
- summarize container status, health, images, ports, start time, and log alert counts
- include sanitized ongoing log alert details with detected error codes
- validate hosted application routes
- estimate page views from `portfolio_service` access logs for the selected report window

The report is uploaded as a GitHub Actions artifact named:

```text
portfolio-platform-report
```

Page-view counts are approximate because they depend on Docker log retention and the configured number of scanned log lines.

Report field definitions and troubleshooting notes are documented in:

```text
deployment/REPORTS.md
```
