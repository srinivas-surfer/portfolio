# Pipeline Documentation

## Governance Flow

```text
Developer branch
  -> Pull request to main
  -> PR code validation
  -> PR approval
  -> Merge to main
  -> Pre-build validation
  -> Build approval
  -> Docker build
  -> Docker Hub push
  -> Image validation
  -> Deploy approval
  -> Docker Hub pull
  -> Deploy only portfolio_service with no dependency restart
  -> Application validation
  -> N-1 local cleanup
```

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

Runs on:

- push to `main` when `portfolio/**`, `docker-compose.yml`, `deployment/scripts/**`, or the workflow changes
- manual `workflow_dispatch`

Jobs:

```text
pre-validation
build
deploy
```

The `build` job uses the `build-approval` environment.

The `deploy` job uses the `production-deploy` environment.

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

Deployment uses the immutable Git SHA tag.

## Service Isolation

The portfolio workflow deploys only:

```text
portfolio_service
```

It must not restart `blog_service`, `projects_service`, `experience_service`, `contact_service`, `npm`, or `db`.

Deployment scripts use `docker compose up -d --no-build --no-deps portfolio_service` so Compose recreates only the requested service. Portfolio no longer depends on `contact_service` at compose startup; contact remains a separately deployable service.
