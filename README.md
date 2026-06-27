# Srinivas Portfolio

Dockerized portfolio site split into small services:

- `portfolio/` - home page and contact form
- `experience/` - career and experience page
- `projects/` - project showcase
- `blog/` - blog listing and posts
- `contact/` - Node.js contact API using Amazon SES SMTP
- `gateway/` - CloudFront and Route 53 gateway notes
- `terraform/` - AWS EC2 host provisioning
  

The root `docker-compose.yml` is the primary local orchestration file. It runs all services on a shared Docker network named `app_default`.

## CI/CD

CI/CD is implemented for:

- `portfolio_service`
- `contact_service`

The pipelines use:

- GitHub Actions on a self-hosted runner
- PR code validation before merge
- Build approval through the `build-approval` GitHub environment
- Docker Hub login, image build, push, and logout
- Immutable Git SHA image tags
- Deploy approval through the `production-deploy` GitHub environment
- Docker Hub pull and deployment of only the targeted service
- Contact runtime environment rendering from GitHub Secrets
- Legacy Nginx Proxy Manager decommission before portfolio takes host port `80`
- N-1 local cleanup for rollback readiness

Required GitHub Secrets:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
DOCKERHUB_NAMESPACE
SMTP_HOST
SMTP_PORT
SMTP_SECURE
SMTP_USER
SMTP_PASS
SES_FROM_EMAIL
SES_TO_EMAIL
CORS_ORIGIN
```

Deployment scripts live in `deployment/scripts/`. Workflow logic should only orchestrate those scripts.

See `deployment/README.md`, `deployment/PIPELINES.md`, `deployment/ROLLBACK.md`, and `deployment/RECOVERY.md`.

## Architecture

```text
Browser
  |
  v
Route 53
  |
  v
CloudFront (:443 public TLS)
  |
  v
EC2 origin (:80)
  |
  v
portfolio_service:80

portfolio_service
  |
  +-- /api/contact -> contact_service:3000
```

`portfolio_service` publishes EC2 host port `80` for CloudFront origin traffic. `contact_service` remains private to the Docker network.

## Run Locally

Create a contact environment file:

```bash
cp contact/.env.example contact/.env
```

Set real Amazon SES SMTP values in `contact/.env` when you want the contact form to send email.

Start the full stack:

```bash
docker compose up -d --build
```

For local builds, `portfolio_service` defaults to:

```text
local/portfolio:latest
```

For CI/CD deployment, the workflow sets:

```text
DOCKERHUB_NAMESPACE=<dockerhub-namespace>
PORTFOLIO_IMAGE_TAG=<git-sha>
CONTACT_IMAGE_TAG=<git-sha>
```

Nginx Proxy Manager is no longer part of the active production path.

## CloudFront And Route 53

Production public traffic should use Route 53 and CloudFront:

```text
portfolio.srinivaspitchubabu.click -> Route 53 alias -> CloudFront -> EC2 origin port 80
```

Use a separate origin DNS record or the EC2 public DNS for the CloudFront origin. Do not point the CloudFront origin at the same hostname that aliases back to CloudFront.

The contact form posts to `/api/contact` on the portfolio service. The portfolio Nginx config proxies that path to `contact_service:3000`.

Production portfolio domain example:

```text
portfolio.srinivaspitchubabu.click -> portfolio_service:80
```

Use CloudFront or the portfolio Nginx config to redirect `/` to `/portfolio` if that path is required.

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
docker compose exec portfolio_service wget -qO- http://contact_service:3000/health
```

## Terraform

Terraform provisions a simple EC2 host, VPC, subnet, route table, and security group. For the CloudFront-origin model, the security group should allow:

- `22` for SSH, controlled by `ssh_cidr_blocks`
- `80` for CloudFront origin traffic
- outbound `587` for Amazon SES SMTP when using the current contact configuration

Example:

```bash
cd terraform
terraform init
terraform apply \
  -var region=ap-south-1 \
  -var ami_id=ami-xxxxxxxx \
  -var key_name=your-keypair \
  -var 'ssh_cidr_blocks=["YOUR_IP/32"]'
```

The EC2 user data installs Docker and Docker Compose. It does not copy this repository or deploy the containers for you.

## Notes

- Replace placeholder GitHub and LinkedIn links in the HTML files with real profile URLs.
- Do not commit real SES SMTP credentials.
- Remove `.DS_Store` files before publishing the repo if you want a cleaner history.
