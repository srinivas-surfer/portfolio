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

### `blog.yml`, `projects.yml`, `experience.yml`

Each static content service has its own workflow.

Runs on:

- push to `main` when its service folder, `docker-compose.yml`, `deployment/scripts/**`, or its workflow changes
- manual `workflow_dispatch`

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
