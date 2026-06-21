# Modular Portfolio Deployment (Portfolio + Blog)

Two containers:
- **portfolio/** → Home, Experience, Projects (served on :8080)
- **blog/** → Blog list + posts (served on :8081)

## Deploy with Terraform
```
cd terraform
terraform init
terraform apply -auto-approve   -var region=ap-south-1   -var ami_id=ami-xxxxxxxx   -var key_name=your-keypair
```
Grab the `public_ip` output for GitHub Actions secrets.

## Configure GitHub Secrets
- `EC2_HOST` → your instance public IP
- `EC2_USER` → usually `ubuntu`
- `EC2_SSH_KEY` → contents of your private key (BEGIN/END lines included)

On push to **portfolio/** or **blog/**, CI uploads files to EC2 and rebuilds containers.

## Deployment architecture

### Services
- **portfolio** → static site on port 8080
- **blog** → static site on port 8081  
- **gateway** → Nginx Proxy Manager on ports 80/443/81 (admin UI)

### Traffic flow
```
User → portfolio.example.com:443 (gateway)
       ↓ (proxy passes to)
       127.0.0.1:8080 (portfolio container)

User → blog.example.com:443 (gateway)
       ↓ (proxy passes to)
       127.0.0.1:8081 (blog container)
```

### Monitoring
- Logs ship from portfolio and blog containers to Grafana Cloud Loki
- Gateway access logs also ship to Grafana Cloud
- Logs labeled by service: `portfolio`, `blog`, `gateway`

---

## Local deployment

### 1. Start the services

```bash
# Build portfolio image
docker build -t portfolio:latest ./portfolio

# Build blog image
docker build -t blog:latest ./blog

# Run portfolio on port 8080
docker run -d --name portfolio_app -p 8080:80 \
  -v $(pwd)/portfolio:/usr/share/nginx/html:ro \
  -v $(pwd)/portfolio/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  -v $(pwd)/logs/portfolio:/var/log/nginx \
  portfolio:latest

# Run blog on port 8081
docker run -d --name blog_app -p 8081:80 \
  -v $(pwd)/blog:/usr/share/nginx/html:ro \
  -v $(pwd)/blog/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  -v $(pwd)/logs/blog:/var/log/nginx \
  blog:latest
```

### 2. Deploy Nginx Proxy Manager

```bash
cd gateway
docker compose -f docker-compose.proxy-manager.yml up -d
```

Access the admin UI at `http://localhost:81`

Default credentials:
- Email: `admin@example.com`
- Password: `changeme`

### 3. Add proxy hosts in the UI

1. Go to **Proxy Hosts** → **Add Proxy Host**
2. For portfolio:
   - Domain: `localhost` (or your domain)
   - Forward to: `127.0.0.1:8080`
3. For blog:
   - Domain: `blog.localhost` (or `blog.your-domain.com`)
   - Forward to: `127.0.0.1:8081`

---

## Production deployment

For production with real domains:

1. Update DNS:
   - `portfolio.example.com` → your server IP
   - `blog.example.com` → your server IP

2. Use the Nginx Proxy Manager UI to add proxy hosts:
   - Enable SSL (Let's Encrypt auto-renewal)
   - Set appropriate domain names

3. Ship logs to Grafana Cloud for monitoring

4. Set up CI/CD pipelines for each service:
   - Separate pipelines for portfolio, blog, monitoring
   - No downtime when updating one service

