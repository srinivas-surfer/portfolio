# Platform HTML Report

The `Platform HTML Report` workflow generates a downloadable HTML artifact named:

```text
portfolio-platform-report
```

The workflow is read-only. It does not build images, restart containers, change DNS, update CloudFront, or modify application state.

The scheduled report runs once per day and emails the HTML report body through Amazon SES SMTP.

## How To Run

Open GitHub Actions and run:

```text
Platform HTML Report
```

Inputs:

```text
base_url                 default: https://portfolio.srinivaspitchubabu.click
log_since                default: 24h
log_tail_lines           default: all
log_alert_detail_limit   default: 40
page_view_log_lines      default: all
```

Scheduled runs use:

```text
https://portfolio.srinivaspitchubabu.click
```

This validates the same public path users take:

```text
Route 53 -> CloudFront -> EC2 origin -> portfolio_service -> private app services
```

Use `http://127.0.0.1` only for manual origin troubleshooting when you want to bypass Route 53, CloudFront, TLS, and public internet routing.

## Schedule

The workflow runs daily at:

```text
03:30 UTC
09:00 IST
```

GitHub schedules use UTC.

## Email Delivery

The scheduled report sends the HTML body by email using SES SMTP.

Required GitHub Secrets:

```text
SMTP_HOST
SMTP_PORT
SMTP_SECURE
SMTP_USER
SMTP_PASS
SES_FROM_EMAIL
SES_TO_EMAIL
```

Optional GitHub Secret:

```text
REPORT_TO_EMAIL
```

If `REPORT_TO_EMAIL` is not configured, the workflow sends the report to `SES_TO_EMAIL`.

## Report Sections

### Host Summary

Shows:

```text
Docker version
Docker Compose version
EC2 disk usage
EC2 memory and swap availability
```

This helps confirm that the runner host has enough capacity for deployments.

### Container Health

Shows one row per service:

```text
Service
Container
Status
Health
Image
Ports
Started
Log Alerts
```

`Status` is the Docker container state, such as `running`.

`Health` is the Docker healthcheck state, such as `healthy`.

`Image` shows the exact Docker image tag currently running.

`Ports` shows public host port bindings. It is normal for private services such as blog, projects, experience, and contact to show `none`.

### Log Alerts

`Log Alerts` is a simple count of container log lines in the selected report window that match alert-like keywords:

```text
error
warn
fail
exception
unhealthy
```

By default, the scheduled report scans Docker logs from the last `24h`.

Important:

- It is not a full alerting system.
- It is not a count of unique incidents.
- It may include old errors that are no longer active.
- A service can be `running` and `healthy` while still showing non-zero log alerts.

To investigate a value manually, run:

```bash
docker logs --since 24h <container_name> | grep -Ei 'error|warn|fail|exception|unhealthy'
```

Example:

```bash
docker logs --since 24h contact_service | grep -Ei 'error|warn|fail|exception|unhealthy'
```

For contact, one log alert often points to an older SMTP failure or validation error. If the container is healthy and `/api/contact` works, treat it as historical until the logs show a current repeated failure.

### Ongoing Log Alert Details

This section prints recent matching log lines behind the `Log Alerts` count.

Columns:

```text
Service
Container
Matched Keyword
Error Code
Log Detail
```

`Matched Keyword` is the first alert-like keyword found in the line, such as `error`, `warn`, `fail`, `exception`, or `unhealthy`.

`Error Code` is extracted when the log line contains one of these patterns:

```text
HTTP 4xx or 5xx status
SMTP responseCode, such as SMTP 535
application/runtime code, such as EAUTH
```

If no code is found, the report shows:

```text
n/a
```

`Log Detail` is a sanitized and truncated copy of the matched line. The report masks email addresses and obvious secret-like values before writing them to the HTML artifact.

The number of detail rows is controlled by:

```text
log_alert_detail_limit
```

The default is `40` rows.

### Application Route Health

The report checks:

```text
/
/blog/
/projects/
/experience/
/contact.html
/api/contact
```

Expected healthy results:

```text
/              200
/blog/         200
/projects/     200
/experience/   200
/contact.html  200
/api/contact   expected-400
```

`expected-400` for `/api/contact` is healthy because the report sends an empty JSON payload to verify the API validation contract without sending a real email.

### Approximate Page Views

Page-view counts are calculated from `portfolio_service` access logs in the selected report window.

The scheduled report scans the last `24h` by default and counts:

```text
/
/blog/
/projects/
/experience/
/contact.html
/api/contact
```

The counts are approximate because they depend on Docker log retention and only cover the selected log window.

The parser supports:

- JSON Nginx access logs from `portfolio_service`
- classic Nginx combined access logs

The report excludes internal health-check traffic such as:

```text
Portfolio-Report-HealthCheck
Wget
curl
HealthCheck
kube-probe
```

## Current Report Interpretation

If the report shows all containers as `running` and `healthy`, and route checks are green, the application is operational.

If page views are `0`, check whether real browser traffic exists in recent Docker logs:

```bash
docker logs --since 24h portfolio_service
```

If there is no recent user traffic in Docker logs, the report cannot count page views.

For production-grade analytics, use CloudFront access logs, CloudFront real-time logs, or a dedicated analytics solution. The current report is a lightweight operational snapshot.
