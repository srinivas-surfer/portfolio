# Contact Service Setup

The contact service is a small Express API in `contact/server.js`. It receives portfolio form submissions and sends email through Amazon SES SMTP.

## Endpoints

```text
GET  /health
POST /api/contact
```

Example contact payload:

```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "company": "Acme Corp",
  "message": "Interested in discussing an opportunity."
}
```

## Environment

Create a local env file:

```bash
cp contact/.env.example contact/.env
```

Required values:

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

Use the SMTP username and password generated from the Amazon SES console for the same region as `SMTP_HOST`. These are not the same as normal AWS access keys.

`SES_FROM_EMAIL` must be verified in Amazon SES. If the AWS account is still in the SES sandbox, the recipient may also need to be verified.

`SES_TO_EMAIL` must be a full email address, not only a domain name. For multiple recipients, use comma-separated email addresses:

```env
SES_TO_EMAIL=portfolio.mentee@outlook.com,second@example.com
```

## Request Flow

```text
Browser
  -> http://portfolio.localhost/contact.html
  -> POST http://portfolio.localhost/api/contact
  -> portfolio_service Nginx
  -> contact_service:3000/api/contact
  -> Amazon SES SMTP
```

The portfolio service owns the `/api/contact` proxy in `portfolio/nginx-server.conf`.

## Local Commands

Start everything:

```bash
docker compose up -d --build
```

Check the API:

```bash
docker compose exec npm curl -s http://contact_service:3000/health
```

Send a test request from inside the network:

```bash
docker compose exec npm curl -s -X POST http://contact_service:3000/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","message":"Test message"}'
```

View logs:

```bash
docker compose logs -f contact_service
```

## Security Notes

- Keep SES SMTP credentials in environment variables or a secret manager, not in source control.
- Restrict `CORS_ORIGIN` to the production portfolio origin.
- Add rate limiting at Nginx Proxy Manager or in the Express app before exposing the form publicly.
- Rotate AWS access keys periodically.
