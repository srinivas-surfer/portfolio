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

trap 'fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

REPORT_HTML_FILE="${REPORT_HTML_FILE:-${REPORT_OUTPUT:-}}"
REPORT_TO_EMAIL="${REPORT_TO_EMAIL:-${SES_TO_EMAIL:-}}"
REPORT_EMAIL_SUBJECT="${REPORT_EMAIL_SUBJECT:-Portfolio Platform 24-hour Report - $(date -u +%Y-%m-%d)}"

for var in SMTP_HOST SMTP_PORT SMTP_SECURE SMTP_USER SMTP_PASS SES_FROM_EMAIL REPORT_TO_EMAIL REPORT_HTML_FILE REPORT_EMAIL_SUBJECT; do
  require_env "$var"
  reject_multiline_value "$var"
done

[[ -f "$REPORT_HTML_FILE" ]] || fail "Report HTML file not found: $REPORT_HTML_FILE"

if ! [[ "$SMTP_PORT" =~ ^[0-9]+$ ]]; then
  fail "SMTP_PORT must be numeric."
fi

if ! [[ "$SMTP_SECURE" =~ ^(true|false)$ ]]; then
  fail "SMTP_SECURE must be true or false."
fi

command -v curl >/dev/null 2>&1 || fail "curl is required to send the report email."

IFS=',' read -r -a raw_recipients <<< "$REPORT_TO_EMAIL"
recipients=()
for raw_recipient in "${raw_recipients[@]}"; do
  recipient="${raw_recipient//[[:space:]]/}"
  [[ -n "$recipient" ]] && recipients+=("$recipient")
done

if (( ${#recipients[@]} == 0 )); then
  fail "At least one report recipient is required."
fi

mail_file=$(mktemp /tmp/portfolio-report-email.XXXXXX.eml)
cleanup_mail_file() {
  rm -f "$mail_file"
}
trap 'cleanup_mail_file' EXIT

{
  printf 'Date: %s\n' "$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"
  printf 'From: <%s>\n' "$SES_FROM_EMAIL"
  printf 'To: %s\n' "$(IFS=', '; printf '%s' "${recipients[*]}")"
  printf 'Subject: %s\n' "$REPORT_EMAIL_SUBJECT"
  printf 'MIME-Version: 1.0\n'
  printf 'Content-Type: text/html; charset=UTF-8\n'
  printf 'Content-Transfer-Encoding: 8bit\n'
  printf '\n'
  cat "$REPORT_HTML_FILE"
} > "$mail_file"

smtp_scheme="smtp"
if [[ "$SMTP_SECURE" == "true" ]]; then
  smtp_scheme="smtps"
fi

smtp_url="${smtp_scheme}://${SMTP_HOST}:${SMTP_PORT}"
curl_args=(
  --silent
  --show-error
  --fail
  --url "$smtp_url"
  --mail-from "$SES_FROM_EMAIL"
  --user "$SMTP_USER:$SMTP_PASS"
  --upload-file "$mail_file"
)

if [[ "$SMTP_SECURE" != "true" ]]; then
  curl_args+=(--ssl-reqd)
fi

for recipient in "${recipients[@]}"; do
  curl_args+=(--mail-rcpt "$recipient")
done

log "INFO" "Sending platform report email to ${#recipients[@]} recipient(s)."
curl "${curl_args[@]}" >/dev/null

cleanup_mail_file
trap - EXIT

log "SUCCESS" "Platform report email sent."
finish "SUCCESS"
