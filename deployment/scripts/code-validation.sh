#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="PR Code Validation"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

log() {
  printf '[%s] %s\n' "$1" "$2"
}

finish() {
  local status="$1"
  local end_time
  end_time=$(date +%s)
  log "$status" "$STAGE finished in $((end_time - START_TIME))s"
}

fail() {
  log "ERROR" "$1"
  finish "FAILED"
  exit 1
}

trap 'fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

required_paths=(
  ".gitignore"
  "README.md"
  "docker-compose.yml"
  "portfolio/Dockerfile"
  "portfolio/index.html"
  "contact/package.json"
  "contact/.env.example"
)

for path in "${required_paths[@]}"; do
  [[ -e "$path" ]] || fail "Required path missing: $path"
done

tracked_env_files=$(git ls-files | grep -E '(^|/)\.env$' || true)
if [[ -n "$tracked_env_files" ]]; then
  log "ERROR" "Tracked .env files are not allowed:"
  printf '%s\n' "$tracked_env_files"
  finish "FAILED"
  exit 1
fi

if command -v docker >/dev/null 2>&1 && compose_available; then
  temp_contact_env="false"
  if [[ ! -f contact/.env && -f contact/.env.example ]]; then
    cp contact/.env.example contact/.env
    temp_contact_env="true"
  fi

  cleanup_temp_env() {
    if [[ "$temp_contact_env" == "true" ]]; then
      rm -f contact/.env
    fi
  }
  trap 'cleanup_temp_env' EXIT

  compose config >/tmp/portfolio-compose-config.out
  cleanup_temp_env
  trap - EXIT
else
  log "WARN" "Docker Compose not available; skipping compose config validation."
  compose_install_hint
fi

if compgen -G "deployment/scripts/*.sh" >/dev/null; then
  for script in deployment/scripts/*.sh; do
    bash -n "$script"
  done
fi

if command -v node >/dev/null 2>&1; then
  node -e "JSON.parse(require('fs').readFileSync('contact/package.json', 'utf8'))"
else
  log "WARN" "Node.js not available; skipping package.json parse validation."
fi

if command -v terraform >/dev/null 2>&1; then
  terraform -chdir=terraform fmt -check
else
  log "WARN" "Terraform not available; skipping terraform fmt validation."
fi

log "SUCCESS" "PR code validation passed."
finish "SUCCESS"
