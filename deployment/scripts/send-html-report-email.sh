#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="HTML Report Email"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

reject_multiline_value() {
  local name="$1"
  local value="${!name:-}"

  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
    fail "Environment variable must be a single line: $name"
  fi
}

cleanup_container_file() {
  if [[ -n "${container_report_file:-}" && -n "${CONTACT_CONTAINER_NAME:-}" ]]; then
    docker exec "$CONTACT_CONTAINER_NAME" rm -f "$container_report_file" >/dev/null 2>&1 || true
  fi
}

trap 'cleanup_container_file; fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

REPORT_HTML_FILE="${REPORT_HTML_FILE:-${REPORT_OUTPUT:-}}"
REPORT_EMAIL_SUBJECT="${REPORT_EMAIL_SUBJECT:-Portfolio Platform 24-hour Report - $(date -u +%Y-%m-%d)}"
REPORT_TO_EMAIL="${REPORT_TO_EMAIL:-}"
CONTACT_CONTAINER_NAME="${CONTACT_CONTAINER_NAME:-contact_service}"

for var in REPORT_HTML_FILE REPORT_EMAIL_SUBJECT CONTACT_CONTAINER_NAME; do
  require_env "$var"
  reject_multiline_value "$var"
done

if [[ -n "$REPORT_TO_EMAIL" ]]; then
  reject_multiline_value REPORT_TO_EMAIL
fi

[[ -f "$REPORT_HTML_FILE" ]] || fail "Report HTML file not found: $REPORT_HTML_FILE"

ensure_docker_stack || fail "Docker/Compose bootstrap failed."

container_id=$(docker ps -q -f "name=^/${CONTACT_CONTAINER_NAME}$")
[[ -n "$container_id" ]] || fail "Contact service container is not running: $CONTACT_CONTAINER_NAME"

container_report_file="/tmp/platform-report-email-${GITHUB_RUN_ID:-local}-$$.html"

log "INFO" "Copying report HTML into $CONTACT_CONTAINER_NAME."
docker cp "$REPORT_HTML_FILE" "${CONTACT_CONTAINER_NAME}:${container_report_file}"

log "INFO" "Sending platform report email through $CONTACT_CONTAINER_NAME."
docker exec -i \
  -w /app \
  -e REPORT_HTML_FILE="$container_report_file" \
  -e REPORT_EMAIL_SUBJECT="$REPORT_EMAIL_SUBJECT" \
  -e REPORT_TO_EMAIL="$REPORT_TO_EMAIL" \
  "$CONTACT_CONTAINER_NAME" \
  node <<'NODE'
const fs = require('fs');
const nodemailer = require('nodemailer');

function requireEnv(name) {
  if (!process.env[name]) {
    throw new Error(`Required environment variable is missing: ${name}`);
  }
}

function parseRecipients(value) {
  return String(value || '')
    .split(',')
    .map(item => item.trim())
    .filter(Boolean);
}

(async () => {
  requireEnv('REPORT_HTML_FILE');
  requireEnv('REPORT_EMAIL_SUBJECT');
  requireEnv('SMTP_HOST');
  requireEnv('SMTP_USER');
  requireEnv('SMTP_PASS');
  requireEnv('SES_FROM_EMAIL');

  const recipients = parseRecipients(process.env.REPORT_TO_EMAIL || process.env.SES_TO_EMAIL);
  if (recipients.length === 0) {
    throw new Error('At least one report recipient is required. Set REPORT_TO_EMAIL or SES_TO_EMAIL.');
  }

  const smtpPort = Number(process.env.SMTP_PORT || 587);
  const html = fs.readFileSync(process.env.REPORT_HTML_FILE, 'utf8');
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: smtpPort,
    secure: process.env.SMTP_SECURE === 'true',
    requireTLS: smtpPort !== 465,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS
    }
  });

  try {
    await transporter.sendMail({
      from: process.env.SES_FROM_EMAIL,
      to: recipients,
      subject: process.env.REPORT_EMAIL_SUBJECT,
      html
    });
    console.log(`Report email sent to ${recipients.length} recipient(s).`);
  } finally {
    transporter.close();
  }
})().catch(error => {
  console.error('Report email failed:', error.message);
  process.exit(1);
});
NODE

cleanup_container_file
trap - ERR

log "SUCCESS" "Platform report email sent."
finish "SUCCESS"
