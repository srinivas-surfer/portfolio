#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Contact Environment Rendering"
CONTACT_ENV_FILE="${CONTACT_ENV_FILE:-contact/.env}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

reject_multiline_value() {
  local name="$1"
  local value="${!name:-}"

  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
    fail "Environment variable must be a single line: $name"
  fi
}

trap 'fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

PORT="${PORT:-3000}"
NODE_ENV="${NODE_ENV:-production}"

for var in SMTP_HOST SMTP_PORT SMTP_SECURE SMTP_USER SMTP_PASS SES_FROM_EMAIL SES_TO_EMAIL CORS_ORIGIN PORT NODE_ENV; do
  require_env "$var"
  reject_multiline_value "$var"
done

if ! [[ "$SMTP_PORT" =~ ^[0-9]+$ ]]; then
  fail "SMTP_PORT must be numeric."
fi

if ! [[ "$SMTP_SECURE" =~ ^(true|false)$ ]]; then
  fail "SMTP_SECURE must be true or false."
fi

mkdir -p "$(dirname "$CONTACT_ENV_FILE")"

umask 077
{
  printf 'SMTP_HOST=%s\n' "$SMTP_HOST"
  printf 'SMTP_PORT=%s\n' "$SMTP_PORT"
  printf 'SMTP_SECURE=%s\n' "$SMTP_SECURE"
  printf 'SMTP_USER=%s\n' "$SMTP_USER"
  printf 'SMTP_PASS=%s\n' "$SMTP_PASS"
  printf 'SES_FROM_EMAIL=%s\n' "$SES_FROM_EMAIL"
  printf 'SES_TO_EMAIL=%s\n' "$SES_TO_EMAIL"
  printf 'CORS_ORIGIN=%s\n' "$CORS_ORIGIN"
  printf 'PORT=%s\n' "$PORT"
  printf 'NODE_ENV=%s\n' "$NODE_ENV"
} > "$CONTACT_ENV_FILE"

chmod 600 "$CONTACT_ENV_FILE"

log "SUCCESS" "Contact runtime environment rendered to $CONTACT_ENV_FILE."
finish "SUCCESS"
