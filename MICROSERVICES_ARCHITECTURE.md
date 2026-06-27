# Microservices Architecture

## Overview

This portfolio is organized as a set of small Docker services. Four services serve static HTML/CSS/JS with Nginx, one service handles contact form email through Amazon SES SMTP, and Nginx Proxy Manager provides the public reverse proxy.

## Services

| Service | Folder | Runtime | Internal Port | Purpose |
| --- | --- | --- | --- | --- |
| `portfolio_service` | `portfolio/` | Nginx | `80` | Home page and contact form |
| `experience_service` | `experience/` | Nginx | `80` | Experience page |
| `projects_service` | `projects/` | Nginx | `80` | Projects page |
| `blog_service` | `blog/` | Nginx | `80` | Blog listing and posts |
| `contact_service` | `contact/` | Node.js/Express | `3000` | Contact form API and Amazon SES SMTP integration |
| `npm` | root compose / `gateway/` | Nginx Proxy Manager | `80`, `81`, `443` | Reverse proxy and TLS management |
| `db` | root compose / `gateway/` | MariaDB | `3306` | Nginx Proxy Manager database |

All services join a Docker network explicitly named `gateway_default`.

## Traffic Flow

```text
User
  |
  v
Nginx Proxy Manager
  |
  +-- portfolio.localhost  -> portfolio_service:80
  +-- experience.localhost -> experience_service:80
  +-- projects.localhost   -> projects_service:80
  +-- blog.localhost       -> blog_service:80

portfolio_service
  |
  +-- /api/contact -> contact_service:3000
```

The contact API is intentionally private by default. Public traffic reaches it only through the portfolio service's `/api/contact` proxy.

## CI/CD Pilot Architecture

Phase 1 CI/CD is scoped to `portfolio_service` only.

```text
Pull Request
  |
  v
PR Code Validation
  |
  v
PR Approval
  |
  v
Merge to main
  |
  v
Build Approval
  |
  v
Build portfolio image
  |
  v
Push to Docker Hub
  |
  v
Image Validation
  |
  v
Deploy Approval
  |
  v
Pull immutable SHA image
  |
  v
docker compose up -d --no-build portfolio_service
```

The pilot does not restart unrelated services. Other service pipelines will be added only after the portfolio pattern is reviewed and approved.

`portfolio_service` is the only Compose service currently parameterized for Docker Hub SHA deployment:

```text
${DOCKERHUB_NAMESPACE}/portfolio:${PORTFOLIO_IMAGE_TAG}
```

## Static Service Layout

Each static service follows this pattern:

```text
service/
  Dockerfile
  nginx-main.conf
  nginx-server.conf
  *.html
  style.css
  script.js
  assets/
```

`nginx-main.conf` contains HTTP-level logging and Nginx defaults. `nginx-server.conf` contains the service server block.

Legacy `nginx.conf` files remain in `portfolio/` and `blog/` for manual container mounting patterns, but the Dockerfiles use the split `nginx-main.conf` and `nginx-server.conf` files.

## Contact Service

The contact API exposes:

```text
GET  /health
POST /api/contact
```

It validates required fields, checks email format, escapes submitted values before building the email body, and sends through Amazon SES SMTP.

Configuration lives in environment variables:

```text
SMTP_HOST
SMTP_PORT
SMTP_SECURE
SMTP_USER
SMTP_PASS
SES_FROM_EMAIL
SES_TO_EMAIL
CORS_ORIGIN
PORT
NODE_ENV
```

Use `contact/.env.example` as the template.

## Local Operation

Start the stack:

```bash
docker compose up -d --build
```

Check service status:

```bash
docker compose ps
```

View logs:

```bash
docker compose logs -f portfolio_service
docker compose logs -f contact_service
```

Stop the stack:

```bash
docker compose down
```

## Production Notes

- Publish only Nginx Proxy Manager ports `80` and `443` publicly.
- Restrict Nginx Proxy Manager admin port `81` to trusted IP addresses.
- Store SES SMTP credentials in a secret manager or runtime environment, not in Git.
- Configure real domains and Let's Encrypt certificates in Nginx Proxy Manager.
- Replace placeholder social profile URLs before publishing the portfolio.

## Terraform

The Terraform module provisions a basic EC2 host and network. It opens `80` and `443` publicly, opens `22` based on `ssh_cidr_blocks`, and opens `81` only when `admin_cidr_blocks` is provided.

The EC2 user data installs Docker and Docker Compose. It does not deploy this repository automatically.
