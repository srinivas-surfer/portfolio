# Rollback Guide

Phase 1 keeps rollback readiness through local N-1 retention for `portfolio_service`.

## Retention Model

Per service, keep:

```text
N   = current successful deployment
N-1 = previous successful deployment
```

The deployment history is written locally on the self-hosted runner:

```text
deployment/releases/portfolio.history
```

This path is ignored by Git.

## Manual Portfolio Rollback

Rollback automation is not part of Phase 1. To manually roll back the portfolio service, select the previous SHA from:

```text
deployment/releases/portfolio.history
```

Then deploy that tag:

```bash
export DOCKERHUB_NAMESPACE=<dockerhub-namespace>
export PORTFOLIO_IMAGE_TAG=<previous-sha>
docker pull "$DOCKERHUB_NAMESPACE/portfolio:$PORTFOLIO_IMAGE_TAG"
docker compose up -d --no-build portfolio_service
```

Validate:

```bash
docker ps --filter name=portfolio_service
docker logs --tail=50 portfolio_service
docker exec portfolio_service wget -qO- http://127.0.0.1/
```

## Important Limits

- Phase 1 does not delete Docker Hub tags.
- Phase 1 does not include an automated rollback workflow.
- N-1 local rollback depends on the EC2 host retaining the image locally.
- If the EC2 host is replaced, pull the rollback SHA from Docker Hub.

