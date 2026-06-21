# Contact Service Setup Guide

## Overview
The contact service is a Node.js Express backend that processes contact form submissions from the portfolio and sends emails via AWS SES.

## Architecture
- **Frontend**: Contact form in `portfolio/contact.html`
- **Backend**: Express.js server in `contact-service/server.js`
- **Email**: AWS SES for sending opportunity inquiries
- **Network**: Docker bridge network (`gateway_default`)

## Service Details

### Endpoints

#### Health Check
```bash
GET /health
Response: { "status": "ok" }
```

#### Contact Form Submission
```bash
POST /api/contact
Content-Type: application/json

Request Body:
{
  "name": "John Doe",
  "email": "john@example.com",
  "company": "Acme Corp",
  "message": "Interested in discussing opportunities..."
}

Response (Success):
{
  "success": true,
  "message": "Your message has been sent successfully. I'll get back to you soon!"
}

Response (Error):
{
  "success": false,
  "error": "Error message here"
}
```

## AWS SES Configuration

### Prerequisites
1. AWS Account with SES access in `ap-south-1` region
2. Verified sender email address in AWS SES
3. AWS IAM credentials with SES send permissions

### Setup Steps

1. **Verify Sender Email in AWS SES**
   - Go to AWS SES console in `ap-south-1` region
   - Navigate to "Verified identities"
   - Add your sender email (e.g., noreply@example.com)
   - Verify the email by clicking the verification link

2. **Create IAM User with SES Permissions**
   ```
   - Go to IAM → Users → Create User
   - Attach policy: AmazonSESFullAccess
   - Create access keys
   - Save Access Key ID and Secret Access Key
   ```

3. **Configure Environment Variables**
   ```bash
   # Copy .env.example to .env
   cp contact-service/.env.example contact-service/.env
   
   # Edit .env with actual values
   AWS_REGION=ap-south-1
   AWS_ACCESS_KEY_ID=your-access-key-here
   AWS_SECRET_ACCESS_KEY=your-secret-key-here
   SES_FROM_EMAIL=noreply@example.com  # Must be verified in SES
   SES_TO_EMAIL=your-email@example.com  # Where to receive contact form submissions
   PORT=3000
   NODE_ENV=production
   ```

## Nginx Proxy Manager Configuration

### Adding Contact Service Proxy Host

1. **Access Nginx Proxy Manager Admin Panel**
   - URL: `http://localhost:81`
   - Username: `admin@example.com`
   - Password: `changeme` (default - change this!)

2. **Create Proxy Host**
   - Go to "Proxy Hosts" → "Add Proxy Host"
   - Fill in the details:
     - **Domain Names**: `contact.localhost` (for local) or your domain
     - **Scheme**: `http`
     - **Forward Hostname/IP**: `contact_service`
     - **Forward Port**: `3000`
   - Enable "Block Common Exploits"
   - Save

3. **Verify in Nginx Config**
   The proxy host creates an Nginx upstream configuration pointing to `contact_service:3000`

### Route from Portfolio

The contact form in `portfolio/contact.html` sends requests to:
```javascript
fetch('/api/contact', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(formData)
})
```

When accessed via `http://portfolio.localhost/contact.html`, the request goes through:
1. Browser → `http://portfolio.localhost/api/contact`
2. Nginx Proxy Manager intercepts
3. Routes to `http://contact_service:3000/api/contact` (same path)

**Note**: The contact form currently submits to `/api/contact`. You have two options:

**Option A**: Create separate proxy host for each domain
- `portfolio.localhost` → `portfolio_app:80`
- `contact.localhost` → `contact_service:3000`
- Update contact form to submit to `http://contact.localhost/api/contact`

**Option B**: Add upstream proxy in portfolio Nginx config
- Create a location block in `portfolio/nginx-server.conf`:
  ```nginx
  location /api/contact {
    proxy_pass http://contact_service:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
  ```

## Deployment

### Using Docker Compose
```bash
# Set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export SES_FROM_EMAIL="noreply@example.com"
export SES_TO_EMAIL="contact@example.com"

# Deploy all services
docker-compose up -d

# Verify services
docker-compose ps
```

### Manual Docker Commands
```bash
# Build contact service
docker build -t contact-service:latest ./contact-service

# Run contact service
docker run -d \
  --name contact_service \
  --network gateway_default \
  -e AWS_REGION=ap-south-1 \
  -e AWS_ACCESS_KEY_ID=your-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret \
  -e SES_FROM_EMAIL=noreply@example.com \
  -e SES_TO_EMAIL=contact@example.com \
  -e PORT=3000 \
  -e NODE_ENV=production \
  contact-service:latest

# Test health
docker exec npm curl -s http://contact_service:3000/health
```

## Testing

### Test Contact Form Submission
```bash
curl -X POST http://contact_service:3000/api/contact \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "company": "Test Corp",
    "message": "This is a test message"
  }'
```

### Check Logs
```bash
# Contact service logs
docker logs contact_service

# Email sending errors typically show here
docker logs contact_service | grep -i error
```

## Common Issues

### 1. Contact form returns 404
- **Cause**: Proxy host not configured in Nginx Proxy Manager
- **Solution**: Add proxy host pointing to `contact_service:3000`

### 2. Emails not being sent (AWS SES errors)
- **Cause**: AWS credentials invalid or sender email not verified
- **Solution**: 
  - Verify credentials in `.env`
  - Check AWS SES console for verified email addresses
  - Check service logs: `docker logs contact_service`

### 3. Container can't reach contact service
- **Cause**: Container not on same network
- **Solution**: Ensure all containers use `--network gateway_default`

### 4. CORS errors from frontend
- **Cause**: CORS headers not set properly
- **Solution**: Contact service includes CORS middleware - verify it's in `server.js`

## Production Considerations

1. **Move to separate host**: Don't expose `:3000` directly in production
2. **Use HTTPS**: Configure SSL certificates in Nginx Proxy Manager
3. **Rate limiting**: Add rate limiting in Nginx Proxy Manager
4. **Secrets management**: Use environment variables or secrets manager (not `.env`)
5. **Monitoring**: Integrate with Grafana Cloud Loki for log aggregation
6. **Health checks**: Kubernetes readiness probes for container orchestration

## Security Best Practices

1. **Change default npm credentials** immediately
2. **Rotate AWS access keys** regularly
3. **Use HTTPS with Let's Encrypt** for production
4. **Implement CORS properly** to restrict origins
5. **Validate and sanitize** all form inputs (already done with `escapeHtml`)
6. **Store secrets** in environment variables, not in source code
7. **Use security headers** in Nginx (CSP, X-Frame-Options, etc.)

## Scaling

For production deployment to AWS:
- Use AWS ECS with Fargate for containerized services
- Use AWS RDS for database
- Use AWS ALB for load balancing
- Use AWS Secrets Manager for credentials
- Use CloudWatch for centralized logging

See `terraform/main.tf` for AWS infrastructure setup.
