#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Smoke Tests"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

trap 'fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

command -v curl >/dev/null 2>&1 || fail "curl is required for smoke tests."

SMOKE_BASE_URL="${SMOKE_BASE_URL:-http://127.0.0.1}"
SMOKE_BASE_URL="${SMOKE_BASE_URL%/}"

check_http_ok() {
  local path="$1"
  local url="${SMOKE_BASE_URL}${path}"

  log "INFO" "Checking $url"
  curl -fsS -o /tmp/smoke-response.out "$url"
}

check_contact_contract() {
  local url="${SMOKE_BASE_URL}/api/contact"
  local status

  log "INFO" "Checking contact API validation contract at $url"
  status=$(curl -sS -o /tmp/smoke-contact-response.out -w '%{http_code}' \
    -X POST "$url" \
    -H "Content-Type: application/json" \
    -d '{}')

  [[ "$status" == "400" ]] || fail "Expected /api/contact empty payload to return 400, got $status."

  if ! grep -q "Missing required fields" /tmp/smoke-contact-response.out; then
    fail "Contact API validation response did not include the expected error message."
  fi
}

check_http_ok "/"
check_http_ok "/blog/"
check_http_ok "/projects/"
check_http_ok "/experience/"
check_contact_contract

log "SUCCESS" "Smoke tests passed for $SMOKE_BASE_URL."
finish "SUCCESS"
