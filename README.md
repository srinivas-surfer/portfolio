# Srinivas Portfolio

Dockerized portfolio site split into small services:

- `portfolio/` - home page and contact form
- `experience/` - career and experience page
- `projects/` - project showcase
- `blog/` - blog listing and posts
- `contact/` - Node.js contact API using Amazon SES SMTP
- `gateway/` - optional standalone Nginx Proxy Manager setup
- `terraform/` - AWS EC2 host provisioning

The root `docker-compose.yml` is the primary local orchestration file. It runs all services on a shared Docker network named `gateway_default`.

## Architecture

```text
Browser
  |
  v
Nginx Proxy Manager (:80, :443, :81 admin)
  |
  +-- portfolio.localhost  -> portfolio_service:80
  +-- experience.localhost -> experience_service:80
  +-- projects.localhost   -> projects_service:80
  +-- blog.localhost       -> blog_service:80

portfolio_service
  |
  +-- /api/contact -> contact_service:3000
```

The static services are private to the Docker network. Only Nginx Proxy Manager publishes host ports.

## Run Locally

Create a contact environment file:

```bash
cp contact/.env.example contact/.env
```

Set real Amazon SES SMTP values in `contact/.env` when you want the contact form to send email.

Optional: copy `.env.example` to `.env` if you want to override the local Nginx Proxy Manager database password defaults.

Start the full stack:

```bash
docker compose up -d --build
```

Open the Nginx Proxy Manager admin UI:

```text
http://localhost:81
```

Default first-login credentials are provided by Nginx Proxy Manager:

```text
Email: admin@example.com
Password: changeme
```

Change that password immediately after first login.

## Proxy Hosts

Create these proxy hosts in Nginx Proxy Manager:

| Domain | Forward Host | Forward Port |
| --- | --- | --- |
| `portfolio.localhost` | `portfolio_service` | `80` |
| `experience.localhost` | `experience_service` | `80` |
| `projects.localhost` | `projects_service` | `80` |
| `blog.localhost` | `blog_service` | `80` |

The contact form posts to `/api/contact` on the portfolio service. The portfolio Nginx config proxies that path to `contact_service:3000`.

## Useful Commands

```bash
docker compose ps
docker compose logs -f portfolio_service
docker compose logs -f contact_service
docker compose restart portfolio_service
docker compose down
```

Build one service:

```bash
docker compose build portfolio_service
```

Test the contact service from inside the Docker network:

```bash
docker compose exec npm curl -s http://contact_service:3000/health
```

## Terraform

Terraform provisions a simple EC2 host, VPC, subnet, route table, and security group. The security group opens:

- `22` for SSH, controlled by `ssh_cidr_blocks`
- `80` for HTTP
- `443` for HTTPS
- `81` for Nginx Proxy Manager admin only when `admin_cidr_blocks` is set

Example:

```bash
cd terraform
terraform init
terraform apply \
  -var region=ap-south-1 \
  -var ami_id=ami-xxxxxxxx \
  -var key_name=your-keypair \
  -var 'ssh_cidr_blocks=["YOUR_IP/32"]' \
  -var 'admin_cidr_blocks=["YOUR_IP/32"]'
```

The EC2 user data installs Docker and Docker Compose. It does not copy this repository or deploy the containers for you.

## Notes

- Replace placeholder GitHub and LinkedIn links in the HTML files with real profile URLs.
- Do not commit real SES SMTP credentials.
- Remove `.DS_Store` files before publishing the repo if you want a cleaner history.
