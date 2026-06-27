# Nginx Proxy Manager Gateway

This folder contains a standalone Nginx Proxy Manager compose file. For normal local development, prefer the root `docker-compose.yml` because it starts the gateway, database, static services, and contact API together.

## Standalone Gateway

```bash
cd gateway
docker compose -f docker-compose.proxy-manager.yml up -d
```

Admin UI:

```text
http://localhost:81
```

Default first-login credentials:

```text
Email: admin@example.com
Password: changeme
```

Change the password immediately after first login.

## Shared Network

The standalone compose file uses the explicit Docker network name `gateway_default`. This matches the root compose file and allows separately launched services to join the same network.

## Proxy Hosts

When the full stack is running, add these proxy hosts:

| Domain | Forward Host | Forward Port |
| --- | --- | --- |
| `portfolio.localhost` | `portfolio_service` | `80` |
| `experience.localhost` | `experience_service` | `80` |
| `projects.localhost` | `projects_service` | `80` |
| `blog.localhost` | `blog_service` | `80` |

The contact API is not exposed as a separate public host by default. `portfolio_service` proxies `/api/contact` to `contact_service:3000`.

## Production Notes

- Enable Let's Encrypt certificates for public domains.
- Restrict access to port `81` by firewall/security group rules.
- Persist the `npm_data`, `npm_letsencrypt`, and `npm_db` volumes.
