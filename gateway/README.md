# Nginx Proxy Manager Setup

This directory contains the Nginx Proxy Manager configuration for managing all reverse proxy routes.

## Quick start

### Deploy
```bash
cd gateway
docker compose -f docker-compose.proxy-manager.yml up -d
```

Nginx Proxy Manager will:
- Listen on port `80` (HTTP)
- Listen on port `443` (HTTPS)
- Provide admin UI on port `81`

### Access the admin UI
1. Open `http://localhost:81`
2. Login with default credentials:
   - Email: `admin@example.com`
   - Password: `changeme`
3. Change password immediately after first login

---

## Add a proxy host

### Example: Add portfolio service

1. In the UI, go to **Proxy Hosts** → **Add Proxy Host**
2. Fill in:
   - Domain: `portfolio.example.com`
   - Scheme: `http`
   - Forward Hostname/IP: `127.0.0.1` (or `portfolio_app` if using Docker networking)
   - Forward Port: `8080`
3. Go to **SSL** tab:
   - Enable **SSL**
   - Request new SSL Certificate
   - Enter your email
   - Accept Terms
4. Click **Save**

### Repeat for blog service
- Domain: `blog.example.com`
- Forward to: `127.0.0.1:8081`

### For future services
- Add new proxy host for each new service
- Same process: domain → forward to internal IP:port → enable SSL

---

## Notes

- All SSL certificates are automatically managed by Let's Encrypt
- Certificates renew automatically
- Each proxy host logs requests through Nginx Proxy Manager
- Add labels in Nginx Proxy Manager to organize proxy hosts

---

## Access logs for Grafana

Nginx Proxy Manager forwards requests through its Nginx instance. Logs can be shipped to Grafana Cloud Loki via:

1. Mount a logs volume from the container:
   ```yaml
   volumes:
     - ./logs:/var/log/npm
   ```

2. Configure Promtail to read `/var/log/npm/access.log`

3. Add labels: `service=gateway` or `service=npm`

This way, Grafana Cloud can see all reverse proxy traffic.
