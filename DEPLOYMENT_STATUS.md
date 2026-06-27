# Deployment Status

Last source audit: June 27, 2026

This file records the expected deployment state from the repository configuration. It does not prove that containers are currently running on any host.

## CI/CD State

CI/CD is implemented for:

- `portfolio_service`
- `contact_service`

The portfolio and contact pipelines build and push Docker Hub images, deploy immutable Git SHA tags, validate running containers, and perform local N-1 cleanup.

The public gateway is Route 53 and CloudFront. `portfolio_service` publishes EC2 host port `80` as the CloudFront origin.

Experience, projects, blog, and the master pipeline still use the existing manual/local deployment model until their pipelines are separately approved and implemented.

## Expected Services

| Service | Container | Internal Port | Public Access |
| --- | --- | --- | --- |
| Portfolio | `portfolio_service` | `80` | Host port `80`, CloudFront origin |
| Experience | `experience_service` | `80` | Private Docker network |
| Projects | `projects_service` | `80` | Private Docker network |
| Blog | `blog_service` | `80` | Private Docker network |
| Contact API | `contact_service` | `3000` | Private, proxied by portfolio `/api/contact` |

## Expected URLs

After Route 53 and CloudFront are configured:

```text
https://portfolio.srinivaspitchubabu.click/
https://portfolio.srinivaspitchubabu.click/portfolio
```

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
- [ ] Run the contact workflow to deploy `contact_service`.
- [ ] Configure CloudFront distribution with ACM certificate in `us-east-1`.
- [ ] Configure Route 53 alias record to CloudFront.
- [ ] Configure `/api/contact*` CloudFront behavior with caching disabled.
- [ ] Restrict EC2 inbound `80` to CloudFront origin-facing ranges where possible.
- [ ] Replace placeholder GitHub and LinkedIn URLs in HTML pages.
- [ ] Remove `.DS_Store` files from the repository.
