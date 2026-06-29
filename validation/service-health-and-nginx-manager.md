# Service Health Checks and CloudFront Gateway Setup

Run these commands from the project root on the EC2 host.

The active production gateway is:

```text
Route 53 -> CloudFront -> EC2 origin port 80 -> portfolio_service
```

Nginx Proxy Manager is no longer part of the active production path.

## 1. Expected Containers

Active production containers:

```text
portfolio_service
blog_service
projects_service
experience_service
contact_service
```

Legacy containers that should not be running:

```text
npm
db
```

Check:

```bash
docker ps
```

## 2. EC2 Origin Health

`portfolio_service` must publish host port `80`.

```bash
docker compose ps portfolio_service
docker ps --filter name=portfolio_service
curl -I http://127.0.0.1
```

Expected Docker port shape:

```text
0.0.0.0:80->80/tcp
```

If port `80` is owned by legacy `npm`, rerun the portfolio workflow or manually run:

```bash
DECOMMISSION_LEGACY_GATEWAY=true deployment/scripts/decommission-legacy-gateway.sh
```

## 3. Internal Service Health Checks

These checks run from inside the Docker network.

The shared application network is:

```text
app_default
```

It is treated as an external network by Docker Compose and is created by the deployment script if missing.

```bash
docker run --rm --network app_default curlimages/curl:latest -fsS http://portfolio_service/
docker run --rm --network app_default curlimages/curl:latest -fsS http://experience_service/
docker run --rm --network app_default curlimages/curl:latest -fsS http://projects_service/
docker run --rm --network app_default curlimages/curl:latest -fsS http://blog_service/
docker run --rm --network app_default curlimages/curl:latest -fsS http://contact_service:3000/health
```

Expected contact service response:

```json
{"status":"ok"}
```

## 4. Logs

Use logs when a service is not reachable.

```bash
docker compose logs --tail=80 portfolio_service
docker compose logs --tail=80 blog_service
docker compose logs --tail=80 projects_service
docker compose logs --tail=80 experience_service
docker compose logs --tail=80 contact_service
```

## 5. Route 53

Recommended records:

```text
portfolio.srinivaspitchubabu.click -> Alias -> CloudFront distribution
origin.srinivaspitchubabu.click -> A record -> EC2 public IP or Elastic IP
```

Do not use `portfolio.srinivaspitchubabu.click` as the CloudFront origin hostname, because that hostname should resolve to CloudFront.

## 6. CloudFront

Recommended distribution settings:

```text
Alternate domain name: portfolio.srinivaspitchubabu.click
Viewer certificate: ACM certificate in us-east-1
Viewer protocol policy: Redirect HTTP to HTTPS
Origin domain: origin.srinivaspitchubabu.click or EC2 public DNS
Origin protocol policy: HTTP only
Origin port: 80
```

Default behavior:

```text
Path pattern: *
Allowed methods: GET, HEAD
Cache policy: Managed-CachingOptimized or short TTL during rollout
```

Contact behavior:

```text
Path pattern: /api/contact*
Allowed methods: GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE
Cache policy: Managed-CachingDisabled
Origin request policy: forward CORS-related headers
```

## 7. Browser Validation

Open:

```text
https://portfolio.srinivaspitchubabu.click/
https://portfolio.srinivaspitchubabu.click/blog/
https://portfolio.srinivaspitchubabu.click/projects/
https://portfolio.srinivaspitchubabu.click/experience/
https://portfolio.srinivaspitchubabu.click/contact.html
```

Local origin smoke checks:

```bash
curl -I http://127.0.0.1/
curl -I http://127.0.0.1/blog/
curl -I http://127.0.0.1/projects/
curl -I http://127.0.0.1/experience/
curl -i -X POST http://127.0.0.1/api/contact -H "Content-Type: application/json" -d '{}'
```

The empty contact payload should return `400 Bad Request`.

If CloudFront returns `502`, check that EC2 port `80` is reachable from the CloudFront origin path.

If CloudFront returns cached stale content, invalidate:

```text
/*
```

## 8. Contact Form Validation

Submit the contact form from the portfolio site.

If it fails, check:

```bash
docker compose logs --tail=80 contact_service
docker compose logs --tail=80 portfolio_service
```

Before testing mail delivery, confirm the running container has the expected SES settings:

```bash
docker compose exec contact_service printenv SMTP_HOST
docker compose exec contact_service printenv SES_FROM_EMAIL
docker compose exec contact_service printenv SES_TO_EMAIL
```

## 9. Direct Contact API Test

```bash
docker run --rm --network app_default curlimages/curl:latest \
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
docker network rm app_default
docker compose up -d --build
```

If the contact service says email is not configured, verify `contact/.env` contains:

```env
SMTP_HOST=email-smtp.us-east-1.amazonaws.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your-ses-smtp-username
SMTP_PASS=your-ses-smtp-password
SES_FROM_EMAIL=no-reply@srinivaspitchubabu.click
SES_TO_EMAIL=portfolio.mentee@outlook.com
CORS_ORIGIN=https://portfolio.srinivaspitchubabu.click,http://portfolio.srinivaspitchubabu.click
PORT=3000
NODE_ENV=production
```

`SES_TO_EMAIL` must be a full email address such as `name@example.com`, not only a domain.
