# AWS Edge Gateway

The production gateway is now AWS-managed:

```text
Route 53 -> CloudFront -> EC2 origin port 80 -> portfolio_service
```

Nginx Proxy Manager and its MariaDB database are no longer part of the active application platform.

## Route 53

Create or update the public application record:

```text
portfolio.srinivaspitchubabu.click
```

Point it to the CloudFront distribution using a Route 53 alias record.

Use a separate origin record or the EC2 public DNS for the CloudFront origin. Do not use the same hostname for both the CloudFront viewer domain and the CloudFront origin.

Example origin record:

```text
origin.srinivaspitchubabu.click -> EC2 public IP
```

Prefer an Elastic IP for the EC2 origin so the origin address does not change after instance stop/start.

## CloudFront

Recommended distribution settings:

```text
Alternate domain name: portfolio.srinivaspitchubabu.click
Viewer certificate: ACM certificate in us-east-1
Viewer protocol policy: Redirect HTTP to HTTPS
Origin domain: origin.srinivaspitchubabu.click or EC2 public DNS
Origin protocol policy: HTTP only
Origin port: 80
```

Recommended behavior for static portfolio content:

```text
Path pattern: Default (*)
Allowed methods: GET, HEAD
Cache policy: Managed-CachingOptimized or a short custom TTL during early rollout
```

The default behavior reaches `portfolio_service`, which internally routes:

```text
/            -> portfolio_service
/blog/       -> blog_service
/projects/   -> projects_service
/experience/ -> experience_service
```

Recommended behavior for the contact API:

```text
Path pattern: /api/contact*
Allowed methods: GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE
Cache policy: Managed-CachingDisabled
Origin request policy: forward headers needed for CORS
```

## EC2 Security Group

Minimum inbound rules:

```text
TCP 80 from CloudFront origin-facing ranges, preferred
TCP 22 from trusted access path only, or use AWS Systems Manager Session Manager
```

No public `81` rule is required because Nginx Proxy Manager is removed.

Minimum outbound rules:

```text
TCP 443 for GitHub, Docker Hub, and AWS APIs
TCP 587 for Amazon SES SMTP
```

## Legacy Gateway Cleanup

The portfolio workflow runs:

```text
deployment/scripts/decommission-legacy-gateway.sh
```

when `DECOMMISSION_LEGACY_GATEWAY=true`. This stops and removes only the legacy `npm` and `db` containers and keeps their Docker volumes intact.
