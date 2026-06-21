# Deployment Status & Quick Reference

## ✅ Current Status

**Date**: June 21, 2024  
**Deployment**: All microservices running  
**Network**: Docker bridge network `gateway_default`

### Running Services

| Service | Container | Status | Port | URL |
|---------|-----------|--------|------|-----|
| Portfolio | portfolio_service | ✅ Running | 80 | `http://portfolio.localhost/` |
| Experience | experience_service | ✅ Running | 80 | `http://experience.localhost/` |
| Projects | projects_service | ✅ Running | 80 | `http://projects.localhost/` |
| Blog | blog_service | ✅ Running | 80 | `http://blog.localhost/` |
| Contact (Backend) | contact_service | ✅ Running | 3000 | Internal API |
| Nginx Proxy Manager | npm | ✅ Running | 80/81/443 | `http://localhost:81` (Admin) |
| MariaDB | db | ✅ Running | 3306 | Internal DB |

## 📁 Project Structure

```
portfolio/
├── portfolio/                    # Portfolio homepage service
│   ├── Dockerfile
│   ├── index.html               # Homepage
│   ├── contact.html             # Contact form page
│   ├── style.css
│   ├── script.js
│   ├── nginx-main.conf
│   ├── nginx-server.conf
│   └── assets/
│
├── experience/                   # Experience service
│   ├── Dockerfile
│   ├── experience.html          # Career page
│   ├── style.css
│   ├── script.js
│   ├── nginx-main.conf
│   ├── nginx-server.conf
│   └── assets/
│
├── projects/                     # Projects service
│   ├── Dockerfile
│   ├── projects.html            # Projects showcase
│   ├── style.css
│   ├── script.js
│   ├── nginx-main.conf
│   ├── nginx-server.conf
│   └── assets/
│
├── blog/                         # Blog service
│   ├── Dockerfile
│   ├── blog.html                # Blog listing
│   ├── posts/
│   │   ├── blog-post1.html
│   │   ├── blog-post2.html
│   │   ├── blog-post3.html
│   │   └── blog-post4.html
│   ├── style.css
│   ├── script.js
│   ├── nginx-main.conf
│   ├── nginx-server.conf
│   └── assets/
│
├── contact/                      # Contact service backend
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json
│   ├── server.js               # Express backend with AWS SES
│   └── .env.example
│
├── gateway/                      # Nginx Proxy Manager gateway
│   ├── docker-compose.proxy-manager.yml
│   └── README.md
│
├── terraform/                    # AWS infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── user_data.sh
│
├── docker-compose.yml            # Main orchestration file
├── MICROSERVICES_ARCHITECTURE.md # This documentation
├── CONTACT_SERVICE_SETUP.md      # Contact service guide
└── README.md                     # Project readme
```

## 🚀 Quick Commands

### Start Services
```bash
# Start all services (from portfolio root)
docker-compose up -d

# Start specific service
docker-compose up -d portfolio_service
```

### Check Status
```bash
# List running services
docker-compose ps

# View service logs
docker-compose logs -f portfolio_service

# Check all logs
docker-compose logs
```

### Access Services
```bash
# Portfolio
http://portfolio.localhost/

# Experience
http://experience.localhost/

# Projects
http://projects.localhost/

# Blog
http://blog.localhost/

# Nginx Proxy Manager Admin
http://localhost:81
  Username: admin@example.com
  Password: changeme
```

### Stop Services
```bash
# Stop all services
docker-compose stop

# Stop specific service
docker-compose stop portfolio_service

# Remove all services and cleanup
docker-compose down -v
```

### Rebuild Services
```bash
# Rebuild all images
docker-compose build --no-cache

# Rebuild specific service
docker-compose build --no-cache portfolio_service

# Rebuild and restart
docker-compose up -d --build
```

## 🔧 Configuration

### Contact Form AWS Setup

1. **Create `.env` file** in `contact/` folder:
   ```bash
   cp contact/.env.example contact/.env
   ```

2. **Edit `.env`** with AWS credentials:
   ```env
   AWS_REGION=ap-south-1
   AWS_ACCESS_KEY_ID=your-key-here
   AWS_SECRET_ACCESS_KEY=your-secret-here
   SES_FROM_EMAIL=noreply@example.com
   SES_TO_EMAIL=your-email@example.com
   ```

3. **Restart contact service**:
   ```bash
   docker-compose restart contact_service
   ```

### Nginx Proxy Manager Setup

1. **First time access**:
   - URL: `http://localhost:81`
   - Username: `admin@example.com`
   - Password: `changeme` (CHANGE THIS!)

2. **Add proxy hosts** for each service:
   - Portfolio: `portfolio.localhost` → `portfolio_service:80`
   - Experience: `experience.localhost` → `experience_service:80`
   - Projects: `projects.localhost` → `projects_service:80`
   - Blog: `blog.localhost` → `blog_service:80`

## 📊 Service Communication

```
External Request
       ↓
Nginx Proxy Manager (Port 80/81/443)
       ↓ (Based on domain name)
   ┌───┴────┬──────────┬─────────┐
   ↓        ↓          ↓         ↓
Portfolio Exp Projects Blog (+ internal API proxy to contact_service:3000)
```

## 🧪 Testing

### Test Portfolio Service
```bash
curl http://localhost/
# (via npm proxy on port 80)
```

### Test Contact API
```bash
curl -X POST http://contact_service:3000/api/contact \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "company": "Test Corp",
    "message": "Test message"
  }'
```

### Test Service Connectivity
```bash
# From npm container
docker exec npm curl -s http://portfolio_service:80 | head -1
docker exec npm curl -s http://experience_service:80 | head -1
docker exec npm curl -s http://projects_service:80 | head -1
docker exec npm curl -s http://blog_service:80 | head -1
docker exec npm curl -s http://contact_service:3000/health
```

## 🐛 Troubleshooting

### Service not responding
```bash
# Check if container is running
docker ps | grep service_name

# View container logs
docker logs service_name

# Restart service
docker-compose restart service_name
```

### Port conflicts
```bash
# Check who's using port 80/81
sudo lsof -i :80
sudo lsof -i :81

# Stop conflicting process
sudo kill -9 <PID>
```

### Network issues
```bash
# Test DNS from container
docker exec npm ping portfolio_service

# Verify network
docker network inspect gateway_default
```

## 📝 Next Steps

- [ ] Configure AWS SES credentials in `contact/.env`
- [ ] Add proxy hosts in Nginx Proxy Manager for each service
- [ ] Change default npm admin password
- [ ] Configure SSL certificates via Let's Encrypt
- [ ] Set up log shipping to Grafana Cloud
- [ ] Deploy to AWS using Terraform
- [ ] Set up GitHub Actions CI/CD

## 📚 Documentation Files

- **MICROSERVICES_ARCHITECTURE.md** - Detailed architecture documentation
- **CONTACT_SERVICE_SETUP.md** - Contact service configuration guide
- **README.md** - Project overview
- **gateway/README.md** - Nginx Proxy Manager setup
- **terraform/README.md** - AWS infrastructure setup (if exists)

## 🔐 Security Notes

1. **Change Nginx Proxy Manager password** immediately
2. **Store AWS credentials** securely (use AWS Secrets Manager for production)
3. **Enable HTTPS** via Let's Encrypt in npm
4. **Use strong passwords** for all services
5. **Validate all form inputs** (already implemented in contact service)
6. **Keep Docker images updated** regularly

## 📈 Scaling Considerations

- **Horizontal Scaling**: Run multiple instances of any service
- **Load Balancing**: Configure in Nginx Proxy Manager
- **Database**: MariaDB persisted via named volume
- **Static Content**: Stateless, can scale infinitely
- **Contact Service**: Depends on AWS SES rate limits

## 🔗 Links & Resources

- Docker Compose: https://docs.docker.com/compose/
- Nginx Proxy Manager: https://nginxproxymanager.com/
- AWS SES: https://aws.amazon.com/ses/
- Terraform: https://www.terraform.io/
- Grafana Cloud Loki: https://grafana.com/loki/
