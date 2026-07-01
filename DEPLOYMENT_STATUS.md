# Deployment Status

Last source audit: June 27, 2026

This file records the expected deployment state from the repository configuration. It does not prove that containers are currently running on any host.

## CI/CD State

CI/CD is implemented for:

- `portfolio_service`
- `blog_service`
- `projects_service`
- `experience_service`
- `contact_service`
- manual full-platform master deployment
- manual rollback workflow
- manual HTML platform report workflow

The service pipelines build and push Docker Hub images, deploy immutable Git SHA tags, validate running containers, and perform local N-1 cleanup. Deployment pipelines are manual-only after merge to `main`; PR code validation remains automatic on pull requests.

The rollback workflow can redeploy an explicit image tag or automatically select the previous successful local release from N-1 history.

The report workflow generates a GitHub Actions HTML artifact with platform health, route checks, log alert counts, and approximate page-view counts.

The public gateway is Route 53 and CloudFront. `portfolio_service` publishes EC2 host port `80` as the CloudFront origin.

Blog, projects, experience, and contact remain private on the Docker network and are exposed through portfolio path routing.

## Expected Services

| Service | Container | Internal Port | Public Access |
| --- | --- | --- | --- |
| Portfolio | `portfolio_service` | `80` | Host port `80`, CloudFront origin |
| Experience | `experience_service` | `80` | Private, proxied by portfolio `/experience/` |
| Projects | `projects_service` | `80` | Private, proxied by portfolio `/projects/` |
| Blog | `blog_service` | `80` | Private, proxied by portfolio `/blog/` |
| Contact API | `contact_service` | `3000` | Private, proxied by portfolio `/api/contact` |

## Expected URLs

After Route 53 and CloudFront are configured:

```text
https://portfolio.srinivaspitchubabu.click/
https://portfolio.srinivaspitchubabu.click/blog/
https://portfolio.srinivaspitchubabu.click/projects/
https://portfolio.srinivaspitchubabu.click/experience/
https://portfolio.srinivaspitchubabu.click/contact.html
```

These pages are expected to render responsively across desktop, tablet, and mobile breakpoints. The navbar collapses into a mobile menu on smaller screens.

## Start Locally

```bash
cp contact/.env.example contact/.env
docker compose up -d --build
```

Set real Amazon SES SMTP values in `contact/.env` before testing real email delivery.

## Check

```bash
docker compose ps
docker compose logs -f portfolio_service
docker compose logs -f contact_service
docker compose logs -f blog_service
docker compose logs -f projects_service
docker compose logs -f experience_service
```

Contact API health check:

```bash
docker compose exec portfolio_service wget -qO- http://contact_service:3000/health
```

## Rebuild

```bash
docker compose build --no-cache portfolio_service
docker compose up -d portfolio_service
```

Rebuild all services:

```bash
docker compose up -d --build
```

## Stop

```bash
docker compose down
```

Remove containers and app network:

```bash
docker compose down -v
```

## Deployment Checklist

- [ ] Configure GitHub Secrets for Docker Hub and contact SMTP.
- [ ] Run the portfolio workflow to deploy `portfolio_service`.
- [ ] Run the blog workflow to deploy `blog_service`.
- [ ] Run the projects workflow to deploy `projects_service`.
- [ ] Run the experience workflow to deploy `experience_service`.
- [ ] Run the contact workflow to deploy `contact_service`.
- [ ] Run the master workflow for a complete platform deployment when needed.
- [ ] Use the rollback workflow for service recovery when needed.
- [ ] Use the report workflow to capture health and traffic snapshots when needed.
- [ ] Configure CloudFront distribution with ACM certificate in `us-east-1`.
- [ ] Configure Route 53 alias record to CloudFront.
- [ ] Configure `/api/contact*` CloudFront behavior with caching disabled.
- [ ] Restrict EC2 inbound `80` to CloudFront origin-facing ranges where possible.
- [ ] Replace placeholder GitHub and LinkedIn URLs in HTML pages.
- [ ] Remove `.DS_Store` files from the repository.
