# Microservices Architecture

## Overview
This portfolio application is now structured as independent microservices, each running in its own Docker container. Each service is self-contained with its own Dockerfile, configuration, and assets.

## Service Structure

```
portfolio/
├── portfolio/          → Portfolio homepage service
├── experience/         → Experience/career page service
├── projects/           → Projects showcase service
├── blog/               → Blog service
├── contact/            → Contact form backend service (Node.js + AWS SES)
├── gateway/            → Nginx Proxy Manager (reverse proxy)
└── docker-compose.yml  → Orchestration file for all services
```

## Services Overview

### 1. **Portfolio Service** (portfolio/)
- **Type**: Nginx static content
- **Port**: 80 (internal)
- **URL**: `http://portfolio.localhost/`
- **Content**: 
  - `index.html` - Homepage with hero section and navigation
  - `contact.html` - Contact form page
- **Assets**: CSS, JavaScript, icons
- **Features**: 
  - Structured logging in JSON format
  - API proxy to contact service (`/api/contact → contact_service:3000`)
  - Theme toggle functionality

### 2. **Experience Service** (experience/)
- **Type**: Nginx static content
- **Port**: 80 (internal)
- **URL**: `http://experience.localhost/`
- **Content**:
  - `experience.html` - Career history and professional experience
- **Assets**: CSS, JavaScript, icons (inherited from portfolio)
- **Features**:
  - Standalone service serving career page
  - Independent logging
  - Navigation to all other services

### 3. **Projects Service** (projects/)
- **Type**: Nginx static content
- **Port**: 80 (internal)
- **URL**: `http://projects.localhost/`
- **Content**:
  - `projects.html` - Portfolio projects showcase
- **Assets**: CSS, JavaScript, icons (inherited from portfolio)
- **Features**:
  - Dedicated projects microservice
  - Separate container for scalability
  - Independent logging

### 4. **Blog Service** (blog/)
- **Type**: Nginx static content
- **Port**: 80 (internal)
- **URL**: `http://blog.localhost/`
- **Content**:
  - `blog.html` - Blog listing page
  - `posts/` directory with individual blog posts:
    - `blog-post1.html` - Terraform Infrastructure
    - `blog-post2.html` - SRE E-commerce Platform
    - `blog-post3.html` - Dynatrace Monitoring
    - `blog-post4.html` - AWS AI Services
- **Assets**: CSS, JavaScript, icons
- **Features**:
  - Independent blog service
  - Navigation to portfolio and other services
  - Structured JSON logging

### 5. **Contact Service** (contact/)
- **Type**: Node.js/Express backend
- **Port**: 3000 (internal)
- **URL**: `http://contact_service:3000` (internal only, accessed via proxy)
- **Endpoints**:
  - `GET /health` - Health check
  - `POST /api/contact` - Contact form submission
- **Features**:
  - AWS SES email integration
  - CORS enabled for cross-origin requests
  - Input validation and XSS protection
  - Environment variable configuration for AWS credentials
- **Dependencies**:
  - `express` - Web framework
  - `aws-sdk` - AWS SES integration
  - `cors` - Cross-origin resource sharing
  - `dotenv` - Environment variables

### 6. **Nginx Proxy Manager** (gateway/)
- **Type**: Nginx Proxy Manager + MariaDB
- **Ports**: 
  - `80` - HTTP traffic
  - `443` - HTTPS traffic
  - `81` - Admin UI
- **Function**: 
  - Central reverse proxy/gateway
  - Routes domain names to backend services
  - Manages SSL certificates
- **Admin URL**: `http://localhost:81`
- **Default Credentials**: `admin@example.com` / `changeme`

## Network Architecture

```
Internet/Local Client
  ↓
Nginx Proxy Manager (Port 80/443/81)
  ├─ portfolio.localhost → portfolio_service:80
  ├─ experience.localhost → experience_service:80
  ├─ projects.localhost → projects_service:80
  ├─ blog.localhost → blog_service:80
  └─ contact.localhost → portfolio_service:80 (form proxy to contact_service:3000)

Docker Bridge Network: gateway_default
  - All services communicate via container names
  - Internal only, not exposed to host
```

## Folder Structure Details

Each service folder (portfolio, experience, projects, blog) contains:

```
service/
├── Dockerfile              → Container definition
├── nginx-main.conf         → Nginx HTTP-level config with log_format
├── nginx-server.conf       → Nginx server block config
├── *.html                  → Content files
├── style.css              → Stylesheet
├── script.js              → Client-side JavaScript
└── assets/                → Images, icons, etc.
```

Contact service folder contains:

```
contact/
├── Dockerfile             → Node.js container definition
├── package.json           → Node dependencies
├── package-lock.json      → Locked dependency versions
├── server.js              → Express backend
├── .env.example           → Configuration template
└── .gitkeep              → Empty placeholder
```

## Deployment

### Using Docker Compose

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f [service_name]

# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Building Individual Services

```bash
# Build specific service
docker build -t portfolio:latest ./portfolio
docker build -t experience:latest ./experience
docker build -t projects:latest ./projects
docker build -t blog:latest ./blog
docker build -t contact-service:latest ./contact

# Build all
for service in portfolio experience projects blog; do
  docker build -t $service:latest ./$service
done
docker build -t contact-service:latest ./contact
```

### Manual Container Deployment

```bash
# Run portfolio service
docker run -d \
  --name portfolio_service \
  --network gateway_default \
  portfolio:latest

# Run experience service
docker run -d \
  --name experience_service \
  --network gateway_default \
  experience:latest

# Run projects service
docker run -d \
  --name projects_service \
  --network gateway_default \
  projects:latest

# Run blog service
docker run -d \
  --name blog_service \
  --network gateway_default \
  blog:latest

# Run contact service with AWS credentials
docker run -d \
  --name contact_service \
  --network gateway_default \
  -e AWS_REGION=ap-south-1 \
  -e AWS_ACCESS_KEY_ID=your-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret \
  -e SES_FROM_EMAIL=noreply@example.com \
  -e SES_TO_EMAIL=contact@example.com \
  contact-service:latest
```

## Configuration

### Nginx Proxy Manager Setup

1. **Access Admin UI**: `http://localhost:81`
2. **Create Proxy Hosts**:

   | Domain | Forward To | Port |
   |--------|-----------|------|
   | `portfolio.localhost` | `portfolio_service` | 80 |
   | `experience.localhost` | `experience_service` | 80 |
   | `projects.localhost` | `projects_service` | 80 |
   | `blog.localhost` | `blog_service` | 80 |

3. **Note**: Contact form is served from portfolio service and internally proxies to contact_service

### AWS SES Configuration

1. **Create `.env` file in contact/ folder**:
   ```
   AWS_REGION=ap-south-1
   AWS_ACCESS_KEY_ID=your-access-key
   AWS_SECRET_ACCESS_KEY=your-secret-key
   SES_FROM_EMAIL=verified-email@example.com
   SES_TO_EMAIL=your-email@example.com
   PORT=3000
   NODE_ENV=production
   ```

2. **Verify SES Email**:
   - Go to AWS SES console in `ap-south-1` region
   - Add and verify email addresses for sending and receiving

3. **Create IAM User** with SES permissions for credentials

## Logging

All services output JSON-formatted logs to stdout, captured by Docker:

```bash
# View logs for specific service
docker logs portfolio_service
docker logs experience_service
docker logs projects_service
docker logs blog_service
docker logs contact_service

# Stream logs
docker logs -f portfolio_service

# View logs since time
docker logs --since 2024-01-01 portfolio_service
```

### Log Format

All Nginx services use JSON structured logging:

```json
{
  "time": "2024-06-21T12:00:00+00:00",
  "remote_addr": "192.168.1.100",
  "client_ip": "",
  "user": "-",
  "host": "portfolio.localhost",
  "request_method": "GET",
  "request_uri": "/",
  "request_protocol": "HTTP/1.1",
  "status": 200,
  "body_bytes_sent": 5353,
  "request_time": 0.001,
  "upstream_response_time": "-",
  "http_referer": "-",
  "http_user_agent": "Mozilla/5.0..."
}
```

## Navigation Flow

All services maintain consistent navigation linking to:

```
Portfolio (home) → About | Experience | Projects | Opportunities | Blog
Experience → About | Experience | Projects | Opportunities | Blog
Projects → About | Experience | Projects | Opportunities | Blog
Blog → About | Experience | Projects | Opportunities | Blog
```

Each link points to the appropriate service URL:
- `http://portfolio.localhost/` - Home
- `http://experience.localhost/` - Experience
- `http://projects.localhost/` - Projects
- `http://portfolio.localhost/contact.html` - Contact form
- `http://blog.localhost/` - Blog

## Scaling & High Availability

### Horizontal Scaling

Run multiple instances of any service:

```bash
docker run -d \
  --name portfolio_service_2 \
  --network gateway_default \
  portfolio:latest
```

Then add load balancing in Nginx Proxy Manager or use Docker Swarm/Kubernetes.

### Health Checks

Contact service includes health endpoint:

```bash
curl http://contact_service:3000/health
# Response: {"status":"ok"}
```

Nginx services implicitly healthy when responding to HTTP requests.

### Volume Persistence

- **Nginx Proxy Manager**: Uses named volumes for data and SSL certs
- **MariaDB**: Uses named volume for database
- **Static Services**: Stateless, no persistence needed

## Monitoring & Observability

### Available Metrics

- Container resource usage: `docker stats`
- Service logs: `docker logs`
- Network connectivity: `docker network inspect gateway_default`
- Running processes: `docker ps`

### Log Aggregation

All services output to stdout. For centralized logging:

1. **Docker Compose logging driver**: Configure in `docker-compose.yml`
2. **Log shipping**: Use Promtail or Docker logging plugin to ship to Grafana Cloud Loki
3. **Log format**: All logs are JSON-structured for easy parsing

### Example: Ship Logs to Grafana Loki

```bash
# Install Promtail
wget https://github.com/grafana/loki/releases/download/v2.9.0/promtail-linux-amd64.zip

# Configure Promtail to read Docker logs and ship to Loki
# Then run: ./promtail -config.file=promtail-config.yaml
```

## Development Workflow

### Making Changes

1. **Modify HTML/CSS/JS** in service folder
2. **Rebuild image**: `docker build -t service:latest ./service/`
3. **Restart container**: `docker-compose restart service_name`
4. **Test**: Visit `http://service.localhost/` in browser

### Testing Contact Form

```bash
# Test contact endpoint
curl -X POST http://contact_service:3000/api/contact \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "company": "Acme",
    "message": "Test message"
  }'
```

### Adding New Services

1. Create new folder: `mkdir new-service/`
2. Add HTML files
3. Copy nginx configs from another service
4. Create Dockerfile
5. Add to docker-compose.yml:
   ```yaml
   new_service:
     build: ./new-service
     image: new-service:latest
     container_name: new_service
     networks:
       - gateway_default
   ```
6. Deploy: `docker-compose up -d new_service`

## Cleanup

```bash
# Remove all services
docker-compose down

# Remove containers and volumes
docker-compose down -v

# Remove images
docker-compose down -v --rmi all

# Remove specific service
docker stop portfolio_service && docker rm portfolio_service

# Prune unused images
docker image prune -a
```

## Troubleshooting

### Service not reachable

```bash
# Check if container is running
docker ps | grep portfolio_service

# Check container logs
docker logs portfolio_service

# Test network connectivity
docker exec npm curl http://portfolio_service:80
```

### Port conflicts

```bash
# Find process using port 80
sudo lsof -i :80

# Find process using port 81
sudo lsof -i :81
```

### DNS resolution issues

```bash
# Test DNS from container
docker exec portfolio_service nslookup portfolio_service

# Test connectivity
docker exec portfolio_service ping experience_service
```

### Contact form not working

```bash
# Check contact service is running
docker ps | grep contact_service

# Test health
docker exec npm curl http://contact_service:3000/health

# Check logs
docker logs contact_service

# Verify AWS credentials
docker exec contact_service env | grep AWS
```

## Production Deployment

### AWS ECS

Deploy with docker-compose to ECS:

```bash
ecs-cli compose -f docker-compose.yml service up
```

### Kubernetes

Convert docker-compose to Kubernetes manifests:

```bash
kompose convert -f docker-compose.yml
kubectl apply -f *.yaml
```

### Infrastructure as Code

Use Terraform to provision AWS resources (see `terraform/` folder):

```bash
cd terraform
terraform apply
```

## References

- Docker Documentation: https://docs.docker.com
- Nginx Proxy Manager: https://nginxproxymanager.com
- AWS SES: https://aws.amazon.com/ses/
- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws
