# Rollback Guide

The service pipelines keep rollback readiness through local N-1 retention for app images.

## Retention Model

Per service, keep:

```text
N   = current successful deployment
N-1 = previous successful deployment
```

The deployment history is written locally on the self-hosted runner. Workflows set:

```text
DEPLOYMENT_STATE_DIR=/home/ec2-user/portfolio-deployment/releases
```

Default script fallback when this variable is not set:

```text
deployment/releases/<service>.history
```

This path is ignored by Git.

## Manual App Rollback

Rollback automation is not implemented yet. To manually roll back an app service, select the previous SHA from its history file.

Portfolio:

```text
deployment/releases/portfolio.history
/home/ec2-user/portfolio-deployment/releases/portfolio.history
```

Contact:

```text
deployment/releases/contact.history
/home/ec2-user/portfolio-deployment/releases/contact.history
```

Static services:

```text
deployment/releases/blog.history
deployment/releases/projects.history
deployment/releases/experience.history
/home/ec2-user/portfolio-deployment/releases/blog.history
/home/ec2-user/portfolio-deployment/releases/projects.history
/home/ec2-user/portfolio-deployment/releases/experience.history
```

Then deploy that tag. Portfolio example:

```bash
export DOCKERHUB_NAMESPACE=<dockerhub-namespace>
export PORTFOLIO_IMAGE_TAG=<previous-sha>
docker pull "$DOCKERHUB_NAMESPACE/portfolio:$PORTFOLIO_IMAGE_TAG"
docker compose up -d --no-build --no-deps portfolio_service
```

Contact example:

```bash
export DOCKERHUB_NAMESPACE=<dockerhub-namespace>
export CONTACT_IMAGE_TAG=<previous-sha>
docker pull "$DOCKERHUB_NAMESPACE/contact:$CONTACT_IMAGE_TAG"
docker compose up -d --no-build --no-deps contact_service
```

Blog example:

```bash
export DOCKERHUB_NAMESPACE=<dockerhub-namespace>
export BLOG_IMAGE_TAG=<previous-sha>
docker pull "$DOCKERHUB_NAMESPACE/blog:$BLOG_IMAGE_TAG"
docker compose up -d --no-build --no-deps blog_service
```

Projects and experience follow the same pattern with `PROJECTS_IMAGE_TAG` / `projects_service` and `EXPERIENCE_IMAGE_TAG` / `experience_service`.

Validate:

```bash
docker ps --filter name=portfolio_service
docker logs --tail=50 portfolio_service
docker exec portfolio_service wget -qO- http://127.0.0.1/
```

Hosted path validation:

```bash
curl -I http://127.0.0.1/
curl -I http://127.0.0.1/blog/
curl -I http://127.0.0.1/projects/
curl -I http://127.0.0.1/experience/
```

Contact validation:

```bash
docker ps --filter name=contact_service
docker logs --tail=50 contact_service
docker exec contact_service wget -qO- http://127.0.0.1:3000/health
```

## CloudFront Origin Recovery

CloudFront and Route 53 are AWS-managed resources and are not rolled back by Docker image tags.

If portfolio rollback is required, roll back `portfolio_service` to the previous SHA and keep EC2 host port `80` bound by `portfolio_service`.

Legacy Nginx Proxy Manager containers are removed by the portfolio workflow, but their Docker volumes are not deleted. They should remain unused unless a separate, approved rollback to the old NPM architecture is planned.

## Frontend UI Rollback

Responsive UI changes roll back the same way as any other service image change. Roll back only the affected service image unless a coordinated frontend release was deployed through the master workflow.

## Important Limits

- The pipelines do not delete Docker Hub tags.
- Automated rollback workflows are not implemented yet.
- N-1 local rollback depends on the EC2 host retaining the image locally.
- If the EC2 host is replaced, pull the rollback SHA from Docker Hub.
