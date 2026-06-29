# Srinivas Portfolio

Dockerized portfolio site split into small services:

- `portfolio/` - home page and contact form
- `experience/` - career and experience page
- `projects/` - project showcase
- `blog/` - blog listing and posts
- `contact/` - Node.js contact API using Amazon SES SMTP
- `gateway/` - CloudFront and Route 53 gateway notes
- `terraform/` - AWS EC2 host provisioning

The root `docker-compose.yml` is the primary local orchestration file. It runs all services on a shared external Docker network named `app_default`. Deployment creates the network if it is missing and does not ask Compose to relabel an existing network.

## CI/CD

CI/CD is implemented for:

- `portfolio_service`
- `blog_service`
- `projects_service`
- `experience_service`
- `contact_service`
- full-platform master deployment

The pipelines use:

- GitHub Actions on a self-hosted runner
- PR code validation before merge
- Manual service or master deployment after merge to `main`
- Build approval through the `build-approval` GitHub environment
- Docker Hub login, image build, push, and logout
- Immutable Git SHA image tags
- Deploy approval through the `production-deploy` GitHub environment
- Docker Hub pull and deployment of only the targeted service
- Contact runtime environment rendering from GitHub Secrets
- Legacy Nginx Proxy Manager decommission before portfolio takes host port `80`
- N-1 local cleanup for rollback readiness
- Sequential master deployment for complete platform releases

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
  +-- /blog -> blog_service:80
  +-- /projects -> projects_service:80
  +-- /experience -> experience_service:80
  +-- /api/contact -> contact_service:3000
```

`portfolio_service` publishes EC2 host port `80` for CloudFront origin traffic. Blog, projects, experience, and contact remain private to the Docker network.

## Responsive UI

The frontend services use responsive navigation, fluid sections, mobile-friendly cards, and touch-sized controls for desktop, tablet, and mobile layouts.

Responsive UI changes affect:

```text
portfolio_service
blog_service
projects_service
experience_service
```

Deploy affected service workflows individually, or use the master workflow for a coordinated frontend rollout.

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

For local builds, service images default to:

```text
local/<service>:latest
```

For CI/CD deployment, the workflow sets:

```text
DOCKERHUB_NAMESPACE=<dockerhub-namespace>
PORTFOLIO_IMAGE_TAG=<git-sha>
BLOG_IMAGE_TAG=<git-sha>
PROJECTS_IMAGE_TAG=<git-sha>
EXPERIENCE_IMAGE_TAG=<git-sha>
CONTACT_IMAGE_TAG=<git-sha>
```

Nginx Proxy Manager is no longer part of the active production path.

## CloudFront And Route 53

Production public traffic should use Route 53 and CloudFront:

```text
portfolio.srinivaspitchubabu.click -> Route 53 alias -> CloudFront -> EC2 origin port 80
```

Use a separate origin DNS record or the EC2 public DNS for the CloudFront origin. Do not point the CloudFront origin at the same hostname that aliases back to CloudFront.

The portfolio service handles public path routing:

```text
/            -> portfolio_service
/blog/       -> blog_service
/projects/   -> projects_service
/experience/ -> experience_service
/api/contact -> contact_service
```

Configure `/api/contact*` in CloudFront with all HTTP methods allowed and caching disabled. Static page paths can use normal caching.

## Useful Commands

```bash
docker compose ps
docker compose logs -f portfolio_service
docker compose logs -f contact_service
docker compose logs -f blog_service
docker compose logs -f projects_service
docker compose logs -f experience_service
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

Test hosted paths through the public origin locally:

```bash
curl -I http://127.0.0.1/
curl -I http://127.0.0.1/blog/
curl -I http://127.0.0.1/projects/
curl -I http://127.0.0.1/experience/
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
