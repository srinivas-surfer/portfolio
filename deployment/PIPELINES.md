# Pipeline Documentation

## Governance Flow

```text
Developer branch
  -> Pull request to main
  -> PR code validation
  -> PR approval
  -> Merge to main
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

### `gateway.yml`

Runs on:

- push to `main` when `gateway/**`, `docker-compose.yml`, `deployment/scripts/**`, or the workflow changes
- manual `workflow_dispatch`

Jobs:

```text
pre-validation
deploy
```

The gateway workflow deploys only:

```text
db
npm
```

It validates host ports `80`, `81`, and `443` before deployment. The ports may be free or already owned by the `npm` container. Any other owner fails the deployment.

The `deploy` job uses the `production-deploy` environment.

### `contact.yml`

Runs on:

- push to `main` when `contact/**`, `docker-compose.yml`, `deployment/scripts/**`, or the workflow changes
- manual `workflow_dispatch`

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

Deployment uses the immutable Git SHA tag.

## Service Isolation

The portfolio workflow deploys only:

```text
portfolio_service
```

It must not restart `blog_service`, `projects_service`, `experience_service`, `contact_service`, `npm`, or `db`.

Deployment scripts use `docker compose up -d --no-build --no-deps <service>` so Compose recreates only the requested service. Portfolio no longer depends on `contact_service` at compose startup; contact remains a separately deployable service.

The gateway workflow is the only current workflow allowed to deploy `db` and `npm`.
