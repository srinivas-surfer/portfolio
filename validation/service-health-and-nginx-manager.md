# Service Health Checks and Nginx Proxy Manager Setup

Run these commands from the project root on the Linux host.

Phase 1 CI/CD currently automates only `portfolio_service`. These validation commands still apply to the full local stack, but the automated portfolio pipeline should restart only `portfolio_service`.

For CI/CD deployment, the portfolio image is expected to come from Docker Hub:

```text
${DOCKERHUB_NAMESPACE}/portfolio:${PORTFOLIO_IMAGE_TAG}
```

The portfolio pipeline validates the container internally with:

```bash
docker exec portfolio_service wget -qO- http://127.0.0.1/
```

## 1. Start Services

```bash
docker compose up -d --build
docker compose ps
```

All containers should show `Up`.

Expected containers:

```text
npm
db
portfolio_service
experience_service
projects_service
blog_service
contact_service
```

## 2. Internal Service Health Checks

These checks run from inside the Docker network.

```bash
docker run --rm --network gateway_default curlimages/curl:latest -fsS http://portfolio_service/
docker run --rm --network gateway_default curlimages/curl:latest -fsS http://experience_service/
docker run --rm --network gateway_default curlimages/curl:latest -fsS http://projects_service/
docker run --rm --network gateway_default curlimages/curl:latest -fsS http://blog_service/
docker run --rm --network gateway_default curlimages/curl:latest -fsS http://contact_service:3000/health
```

Expected contact service response:

```json
{"status":"ok"}
```

## 3. Logs

Use logs when a service is not reachable.

```bash
docker compose logs -f npm
docker compose logs -f portfolio_service
docker compose logs -f experience_service
docker compose logs -f projects_service
docker compose logs -f blog_service
docker compose logs -f contact_service
```

## 4. Nginx Proxy Manager Login

Open the admin UI:

```text
http://localhost:81
```

For a remote server:

```text
http://SERVER_PUBLIC_IP:81
```

Default first-login credentials:

```text
Email: admin@example.com
Password: changeme
```

Change the password immediately after login.

## 5. Add Proxy Hosts

In Nginx Proxy Manager:

```text
Proxy Hosts -> Add Proxy Host
```

Create these proxy hosts:

| Domain | Scheme | Forward Hostname | Forward Port |
| --- | --- | --- | --- |
| `portfolio.localhost` | `http` | `portfolio_service` | `80` |
| `experience.localhost` | `http` | `experience_service` | `80` |
| `projects.localhost` | `http` | `projects_service` | `80` |
| `blog.localhost` | `http` | `blog_service` | `80` |

Recommended options:

```text
Block Common Exploits: enabled
Websockets Support: disabled unless needed
```

Do not create a public proxy host for `contact_service`. The portfolio service proxies `/api/contact` internally to `contact_service:3000`.

## 6. Local Hostname Setup

If local domains do not resolve, update `/etc/hosts`:

```bash
sudo nano /etc/hosts
```

For local testing:

```text
127.0.0.1 portfolio.localhost experience.localhost projects.localhost blog.localhost
```

For a remote server, use the server IP:

```text
SERVER_PUBLIC_IP portfolio.localhost experience.localhost projects.localhost blog.localhost
```

## 7. Browser Validation

Open:

```text
http://portfolio.localhost/
http://experience.localhost/
http://projects.localhost/
http://blog.localhost/
http://portfolio.localhost/contact.html
```

## 8. Contact Form Validation

Submit the contact form from:

```text
http://portfolio.localhost/contact.html
```

If it fails, check:

```bash
docker compose logs -f contact_service
docker compose logs -f portfolio_service
```

Before testing mail delivery, confirm the running container has the expected SES settings:

```bash
docker compose exec contact_service printenv SMTP_HOST
docker compose exec contact_service printenv SES_FROM_EMAIL
docker compose exec contact_service printenv SES_TO_EMAIL
```

Expected:

```text
email-smtp.ap-south-1.amazonaws.com
no-reply@srinivaspitchubabu.click
portfolio.mentee@outlook.com
```

## 9. Direct Contact API Test

```bash
docker run --rm --network gateway_default curlimages/curl:latest \
  -s -X POST http://contact_service:3000/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","message":"SMTP test"}'
```

Expected successful response:

```json
{"success":true,"message":"Email sent successfully"}
```

## 10. Common Fixes

If the network has a stale label:

```bash
docker compose down
docker network rm gateway_default
docker compose up -d --build
```

If Nginx Proxy Manager is not reachable:

```bash
docker compose ps npm
docker compose logs -f npm
```

If the contact service says email is not configured, verify `contact/.env` contains:

```env
SMTP_HOST=email-smtp.ap-south-1.amazonaws.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your-ses-smtp-username
SMTP_PASS=your-ses-smtp-password
SES_FROM_EMAIL=no-reply@srinivaspitchubabu.click
SES_TO_EMAIL=portfolio.mentee@outlook.com
CORS_ORIGIN=http://portfolio.localhost
PORT=3000
NODE_ENV=production
```

`SES_TO_EMAIL` must be a full email address such as `name@example.com`, not only a domain.
