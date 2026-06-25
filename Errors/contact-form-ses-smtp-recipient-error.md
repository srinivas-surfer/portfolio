Contact service error

docker compose logs -f contact_service
contact_service  | 
contact_service  | > contact-service@1.0.0 start
contact_service  | > node server.js
contact_service  | 
contact_service  | Contact service listening on port 3000
contact_service  | SES SMTP Error: Error: No recipients defined
contact_service  |     at SMTPConnection._formatError (/app/node_modules/nodemailer/lib/smtp-connection/index.js:809:19)
contact_service  |     at SMTPConnection._setEnvelope (/app/node_modules/nodemailer/lib/smtp-connection/index.js:1047:34)
contact_service  |     at SMTPConnection.send (/app/node_modules/nodemailer/lib/smtp-connection/index.js:631:14)
contact_service  |     at sendMessage (/app/node_modules/nodemailer/lib/smtp-transport/index.js:228:28)
contact_service  |     at /app/node_modules/nodemailer/lib/smtp-transport/index.js:286:25
contact_service  |     at SMTPConnection._actionAUTHComplete (/app/node_modules/nodemailer/lib/smtp-connection/index.js:1602:9)
contact_service  |     at SMTPConnection.<anonymous> (/app/node_modules/nodemailer/lib/smtp-connection/index.js:556:26)
contact_service  |     at SMTPConnection._processResponse (/app/node_modules/nodemailer/lib/smtp-connection/index.js:993:20)
contact_service  |     at SMTPConnection._onData (/app/node_modules/nodemailer/lib/smtp-connection/index.js:774:14)
contact_service  |     at SMTPConnection._onSocketData (/app/node_modules/nodemailer/lib/smtp-connection/index.js:195:44) {
contact_service  |   code: 'EENVELOPE',
contact_service  |   command: 'API'
contact_service  | }
^Z

Portfolio service logs

mentee@mentees-ubuntu:~/Desktop/Git/portfolio$ docker compose logs -f portfolio_service
portfolio_service  | /docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
portfolio_service  | /docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
portfolio_service  | /docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
portfolio_service  | 10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
portfolio_service  | 10-listen-on-ipv6-by-default.sh: info: /etc/nginx/conf.d/default.conf differs from the packaged version
portfolio_service  | /docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
portfolio_service  | /docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
portfolio_service  | /docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
portfolio_service  | /docker-entrypoint.sh: Configuration complete; ready for start up
portfolio_service  | {"time":"2026-06-25T12:47:43+00:00","remote_addr":"172.19.0.9","client_ip":"","user":"","host":"portfolio_service","request_method":"GET","request_uri":"/","request_protocol":"HTTP/1.1","status":"200","body_bytes_sent":"5780","request_time":"0.000","upstream_response_time":"","http_referer":"","http_user_agent":"curl/8.21.0"}
portfolio_service  | {"time":"2026-06-25T12:51:58+00:00","remote_addr":"172.19.0.7","client_ip":"172.19.0.1","user":"","host":"portfolio.localhost","request_method":"GET","request_uri":"/","request_protocol":"HTTP/1.1","status":"200","body_bytes_sent":"5780","request_time":"0.000","upstream_response_time":"","http_referer":"http://localhost:81/","http_user_agent":"Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0"}
portfolio_service  | {"time":"2026-06-25T12:51:58+00:00","remote_addr":"172.19.0.7","client_ip":"172.19.0.1","user":"","host":"portfolio.localhost","request_method":"GET","request_uri":"/style.css","request_protocol":"HTTP/1.1","status":"200","body_bytes_sent":"2732","request_time":"0.000","upstream_response_time":"","http_referer":"http://portfolio.localhost/","http_user_agent":"Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0"}
portfolio_service  | {"time":"2026-06-25T12:51:58+00:00","remote_addr":"172.19.0.7","client_ip":"172.19.0.1","user":"","host":"portfolio.localhost","request_method":"GET","request_uri":"/script.js","request_protocol":"HTTP/1.1","status":"200","body_bytes_sent":"1101","request_time":"0.000","upstream_response_time":"","http_referer":"http://portfolio.localhost/","http_user_agent":"Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0"}
portfolio_service  | {"time":"2026-06-25T12:51:58+00:00","remote_addr":"172.19.0.7","client_ip":"172.19.0.1","user":"","host":"portfolio.localhost","request_method":"GET","request_uri":"/assets/icons/github.svg","request_protocol":"HTTP/1.1","status":"304","body_bytes_sent":"0","request_time":"0.000","upstream_response_time":"","http_referer":"http://portfolio.localhost/","http_user_agent":"Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0"}
portfolio_service  | {"time":"2026-06-25T12:51:58+00:00","remote_addr":"172.19.0.7","client_ip":"172.19.0.1","user":"","host":"portfolio.localhost","request_method":"GET","request_uri":"/assets/icons/linkedin.svg","request_protocol":"HTTP/1.1","status":"304","body_bytes_sent":"0","request_time":"0.000","upstream_response_time":"","http_referer":"http://portfolio.localhost/","http_user_agent":"Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0"}
portfolio_service  | {"time":"2026-06-25T12:51:58+00:00","remote_addr":"172.19.0.7","client_ip":"172.19.0.1","user":"","host":"portfolio.localhost","request_method":"GET","request_uri":"/assets/icons/mail.svg","request_protocol":"HTTP/1.1","status":"304","body_bytes_sent":"0","request_time":"0.000","upstream_response_time":"","http_referer":"http://portfolio.localhost/","http_user_agent":"Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0"}
portfolio_service  | {"time":"2026-06-25T12:52:13+00:00","remote_addr":"172.19.0.7","client_ip":"172.19.0.1","user":"","host":"portfolio.localhost","request_method":"GET","request_uri":"/contact.html","request_protocol":"HTTP/1.1","status":"200","body_bytes_sent":"4240","request_time":"0.000","upstream_response_time":"","http_referer":"http://portfolio.localhost/","http_user_agent":"Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0"}
portfolio_service  | {"time":"2026-06-25T12:52:50+00:00","remote_addr":"172.19.0.7","client_ip":"172.19.0.1","user":"","host":"portfolio.localhost","request_method":"POST","request_uri":"/api/contact","request_protocol":"HTTP/1.1","status":"500","body_bytes_sent":"32","request_time":"2.964","upstream_response_time":"2.965","http_referer":"http://portfolio.localhost/contact.html","http_user_agent":"Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0"}
^Z
[2]+  Stopped                 docker compose logs -f portfolio_service


Direct API Validation

mentee@mentees-ubuntu:~/Desktop/Git/portfolio$ docker run --rm --network gateway_default curlimages/curl:latest \
  -s -X POST http://contact_service:3000/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","message":"SMTP test"}'
{"error":"Failed to send email"}m

## Solution

### Root Cause

The contact form reached the backend correctly:

```text
POST /api/contact -> 500
```

The portfolio Nginx proxy also worked correctly because the request reached `contact_service`.

The real failure is in the contact service SMTP send:

```text
SES SMTP Error: Error: No recipients defined
code: 'EENVELOPE'
```

This means Nodemailer did not receive a valid `to` recipient. The usual cause is one of these:

- `SES_TO_EMAIL` is missing in `contact/.env`.
- `SES_TO_EMAIL` is blank.
- `SES_TO_EMAIL` is set to a domain instead of a full email address, for example `portfolio.mentee.com`.

`SES_TO_EMAIL` must be a full email address:

```env
SES_TO_EMAIL=name@example.com
```

If your SES account is still in sandbox mode, this recipient email must also be verified in Amazon SES.

### Repo Fix Applied

Updated `contact/server.js` so the service validates email configuration before calling SMTP:

- `SES_FROM_EMAIL` must be a valid email address.
- `SES_TO_EMAIL` must contain at least one valid email address.
- Multiple recipients are supported with comma-separated values.

If the config is wrong now, the service logs a clear message like:

```text
SMTP configuration error: SES_TO_EMAIL must contain at least one valid email address
```

### Linux Fix

Edit the runtime env file:

```bash
nano contact/.env
```

Use values like:

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

Then rebuild and restart:

```bash
docker compose up -d --build contact_service portfolio_service
```

Watch logs:

```bash
docker compose logs -f contact_service
```

Test directly:

```bash
docker run --rm --network gateway_default curlimages/curl:latest \
  -s -X POST http://contact_service:3000/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","message":"SMTP test"}'
```

Expected success:

```json
{"success":true,"message":"Email sent successfully"}
```

If the response is:

```json
{"error":"Email service is not configured"}
```

then check `docker compose logs -f contact_service` for the exact missing or invalid environment variable.

### Applied Update

The repo has been updated with the final contact mail values we decided to use:

```env
SES_FROM_EMAIL=no-reply@srinivaspitchubabu.click
SES_TO_EMAIL=portfolio.mentee@outlook.com
```

Updated files:

- `contact/.env`
- `contact/.env.example`
- `CONTACT_SERVICE_SETUP.md`
- `validation/service-health-and-nginx-manager.md`
- `Errors/contact-form-ses-smtp-recipient-error.md`

`contact/server.js` was also updated to validate SMTP email configuration before sending. If `SES_TO_EMAIL` is invalid or missing, the service now returns a configuration error instead of reaching Nodemailer with `No recipients defined`.

Before running in production, make sure:

- `no-reply@srinivaspitchubabu.click` is verified in Amazon SES.
- `portfolio.mentee@outlook.com` is verified too if the SES account is still in sandbox mode.
- `SMTP_USER` and `SMTP_PASS` in `contact/.env` contain real SES SMTP credentials.

