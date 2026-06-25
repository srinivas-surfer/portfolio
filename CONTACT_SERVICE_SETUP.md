# Contact Service Setup

The contact service is a small Express API in `contact/server.js`. It receives portfolio form submissions and sends email through AWS SES.

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
AWS_REGION=ap-south-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
SES_FROM_EMAIL=verified-sender@example.com
SES_TO_EMAIL=destination@example.com
CORS_ORIGIN=http://portfolio.localhost
PORT=3000
NODE_ENV=production
```

`SES_FROM_EMAIL` must be verified in AWS SES. If the AWS account is still in the SES sandbox, the recipient may also need to be verified.

## Request Flow

```text
Browser
  -> http://portfolio.localhost/contact.html
  -> POST http://portfolio.localhost/api/contact
  -> portfolio_service Nginx
  -> contact_service:3000/api/contact
  -> AWS SES
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

- Keep AWS credentials in environment variables or a secret manager, not in source control.
- Restrict `CORS_ORIGIN` to the production portfolio origin.
- Add rate limiting at Nginx Proxy Manager or in the Express app before exposing the form publicly.
- Rotate AWS access keys periodically.
