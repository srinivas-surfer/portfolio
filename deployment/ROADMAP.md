# Platform Roadmap

This file tracks upcoming phases for the Portfolio platform.

These phases are planning items only. No architecture, workflow, deployment, runtime, or code changes should be implemented from this roadmap without explicit approval from the Solution Discussion Manager / Approval Authority.

## Current Baseline

Completed platform capabilities:

```text
service-specific CI/CD pipelines
manual-only deployment workflows
PR code validation
Docker Hub build and pull deployment flow
N-1 rollback readiness
rollback workflow
CloudFront and Route 53 public hosting path
daily 24-hour HTML platform report
email delivery through contact_service
platform health score
deployment version and rollback readiness report
runtime security snapshot
performance summary
page-view approximation from access logs
```

## Phase 2.5: CI/CD And Runtime Hygiene

Status:

```text
Proposed
Not approved for implementation
```

Goal:

Remove configuration drift and improve build/runtime predictability before deeper security hardening.

Scope:

```text
remove or replace stale root Docker image workflow
make Compose validation avoid rendering env-file secrets
add contact package-lock.json for repeatable npm installs
upgrade contact service Node image to a supported LTS version
configure Express proxy trust for contact rate limiting
document local external network creation for docker compose up
clean tracked generated files such as .DS_Store and empty logs
```

Likely impacted files:

```text
.github/workflows/build.yml
deployment/scripts/code-validation.sh
deployment/scripts/pre-validation.sh
contact/package-lock.json
contact/Dockerfile
contact/server.js
README.md
.gitignore
```

Recommended rollout order:

```text
CI workflow cleanup
secret-safe validation changes
dependency lockfile and Node image upgrade
proxy-aware contact rate limiting
local documentation updates
repository hygiene cleanup
```

Risks:

```text
removing a workflow can affect existing GitHub branch protection rules
Node image upgrades can expose dependency/runtime compatibility issues
proxy trust must match the deployment topology to avoid trusting spoofed client IPs
cleanup of tracked ignored files should avoid deleting useful local runtime data
```

Validation:

```text
PR code validation
docker compose config -q --no-env-resolution
contact service healthcheck
contact API validation contract
service workflow dry review
git status review for tracked cleanup
```

## Phase 2.6: Excel-Driven Experience Content

Status:

```text
Proposed
Not approved for implementation
```

Goal:

Make Experience page content easier to update by using an Excel workbook as the source of truth during deployment.

Scope:

```text
define Experience workbook schema
store Experience page content in an Excel file
generate static JSON from Excel during build or deployment
render Experience summary and role cards from generated JSON
validate required workbook columns before deployment
document the content update workflow
```

Out of current scope:

```text
This phase is not part of the current static Experience page layout change.
```

Likely impacted files:

```text
experience/content/experience.xlsx
experience/scripts/build-content.js
experience/package.json
experience/Dockerfile
experience/experience.html
experience/script.js
README.md
MICROSERVICES_ARCHITECTURE.md
deployment/README.md
```

Recommended rollout order:

```text
agree workbook schema
add build-time Excel to JSON generator
render Experience page from generated JSON
add validation for missing or malformed workbook data
document deployment/content update workflow
```

Risks:

```text
invalid workbook formatting can break generated content
date format inconsistencies can produce wrong experience totals
build dependencies add maintenance overhead
runtime Excel parsing should be avoided to keep the static service simple
```

Validation:

```text
Excel schema validation
generated JSON review
Experience page route check
mobile and desktop visual check
experience_service image build
```

## Phase 3: Container Security Hardening

Status:

```text
Proposed
Not approved for implementation
```

Goal:

Reduce container runtime risk and improve the security posture shown in the daily platform report.

Scope:

```text
review container users
run services as non-root where practical
add read-only root filesystems where safe
add tmpfs mounts for runtime write paths
add no-new-privileges
drop Linux capabilities where safe
keep private services without host port bindings
document accepted exceptions
```

Likely impacted files:

```text
docker-compose.yml
portfolio/Dockerfile
blog/Dockerfile
projects/Dockerfile
experience/Dockerfile
contact/Dockerfile
deployment/README.md
deployment/REPORTS.md
deployment/RECOVERY.md
```

Recommended rollout order:

```text
blog
projects
experience
portfolio
contact
```

Risks:

```text
read-only filesystem can break Nginx cache/temp paths
non-root containers can break privileged port binding
Node contact service may need writable temp paths
over-hardening can cause startup or healthcheck failures
```

Validation:

```text
docker compose config
service healthchecks
public route checks
contact email test
HTML report review
rollback readiness check
```

## Phase 4: Monitoring And Alerting Expansion

Status:

```text
Backlog
Not approved for implementation
```

Goal:

Move from daily visibility to active operational awareness.

Scope options:

```text
Prometheus scrape validation
Node Exporter host metrics
cAdvisor container metrics
Dozzle log review
Grafana Cloud dashboard integration
alert rules for service down, high memory, high disk, restart loops
email or Slack alert path
```

Design notes:

```text
avoid exposing monitoring ports publicly unless explicitly approved
prefer private access, VPN, Cloudflare Tunnel, or security-group restricted access
keep Grafana Cloud as the visualization layer if chosen
```

Risks:

```text
small EC2 instance memory pressure
public monitoring ports increase attack surface
too many alerts can create noise
```

## Phase 5: Backup And Disaster Recovery

Status:

```text
Backlog
Not approved for implementation
```

Goal:

Document and validate recovery paths for code, images, release history, secrets, and runtime state.

Scope options:

```text
backup deployment release history
backup contact runtime env generation process
backup Docker Compose config snapshots
document EC2 rebuild steps
document Docker Hub image recovery
document CloudFront and Route 53 recovery checks
add backup status to HTML report
```

Risks:

```text
backups may accidentally include secrets if not filtered
release history backup location must survive EC2 replacement
manual recovery steps can drift without periodic testing
```

## Phase 6: DevSecOps Scanning

Status:

```text
Backlog
Not approved for implementation
```

Goal:

Add security scanning before image build and before production deployment.

Scope options:

```text
Trivy image scan
Gitleaks secret scan
dependency vulnerability checks
Dockerfile best-practice checks
SARIF upload to GitHub code scanning if enabled
security summary in pull requests
security summary in platform report
```

Risks:

```text
new scans can fail existing builds
false positives require triage policy
scans can add pipeline runtime
private Docker Hub images may require authenticated scanning
```

## Phase 7: Analytics And Access Reporting

Status:

```text
Backlog
Not approved for implementation
```

Goal:

Replace approximate Docker-log page counts with more reliable user traffic reporting.

Scope options:

```text
CloudFront standard logs
CloudFront real-time logs
S3 log storage
Athena query layer
daily traffic summary in HTML report
top paths and status codes
client geography summary if required
bot and healthcheck filtering
```

Risks:

```text
CloudFront logs add AWS storage and query cost
access logs may contain sensitive request metadata
retention and privacy policy must be defined
```

## Approval Gate

Before any phase starts:

```text
confirm approval authority
explain design
explain advantages
explain disadvantages
explain risks
identify impacted services and files
wait for explicit approval from the Solution Discussion Manager / Approval Authority
```
