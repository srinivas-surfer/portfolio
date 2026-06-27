# Deployment Status

Last source audit: June 25, 2026

This file records the expected deployment state from the repository configuration. It does not prove that containers are currently running on any host.

## CI/CD Pilot State

Phase 1 CI/CD is implemented only for `portfolio_service`.

The portfolio pipeline builds and pushes Docker Hub images, deploys an immutable Git SHA tag, validates the running container, and performs local N-1 cleanup.

Other services still use the existing manual/local deployment model until their pipelines are separately approved and implemented.

## Expected Services

| Service | Container | Internal Port | Public Access |
| --- | --- | --- | --- |
| Portfolio | `portfolio_service` | `80` | Via Nginx Proxy Manager |
| Experience | `experience_service` | `80` | Via Nginx Proxy Manager |
| Projects | `projects_service` | `80` | Via Nginx Proxy Manager |
| Blog | `blog_service` | `80` | Via Nginx Proxy Manager |
| Contact API | `contact_service` | `3000` | Private, proxied by portfolio `/api/contact` |
| Nginx Proxy Manager | `npm` | `80`, `81`, `443` | Host ports `80`, `81`, `443` |
| MariaDB | `db` | `3306` | Private Docker network |

## Expected URLs

After proxy hosts are configured in Nginx Proxy Manager:

```text
http://portfolio.localhost/
http://experience.localhost/
http://projects.localhost/
http://blog.localhost/
http://portfolio.localhost/contact.html
```

Admin UI:

```text
http://localhost:81
```

## Start

```bash
cp contact/.env.example contact/.env
docker compose up -d --build
```

Set real Amazon SES SMTP values in `contact/.env` before testing real email delivery.
Copy `.env.example` to `.env` only when you want to override the Nginx Proxy Manager database password defaults.

## Check

```bash
docker compose ps
docker compose logs -f npm
docker compose logs -f portfolio_service
docker compose logs -f contact_service
```

Contact API health check:

```bash
docker compose exec npm curl -s http://contact_service:3000/health
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

Remove persistent Nginx Proxy Manager data as well:

```bash
docker compose down -v
```

## Deployment Checklist

- [ ] Set real Amazon SES SMTP values in `contact/.env` or production environment variables.
- [ ] Configure Nginx Proxy Manager proxy hosts.
- [ ] Change the default Nginx Proxy Manager admin password.
- [ ] Restrict port `81` to trusted IP ranges.
- [ ] Enable HTTPS certificates for production domains.
- [ ] Replace placeholder GitHub and LinkedIn URLs in HTML pages.
- [ ] Remove `.DS_Store` files from the repository.
- [ ] Add CI/CD once the deployment target is finalized.
