#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Service Rollback"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

trap 'fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

rollback_service="${ROLLBACK_SERVICE:-${SERVICE_NAME:-}}"
[[ -n "$rollback_service" ]] || fail "ROLLBACK_SERVICE is required."

if [[ "${ROLLBACK_CONFIRM:-}" != "ROLLBACK" ]]; then
  fail "Rollback confirmation failed. Set ROLLBACK_CONFIRM=ROLLBACK."
fi

set_service_context "$rollback_service"

for var in DOCKERHUB_USERNAME DOCKERHUB_TOKEN DOCKERHUB_NAMESPACE; do
  require_env "$var"
done

release_dir="${DEPLOYMENT_STATE_DIR:-deployment/releases}"
release_file="${release_dir}/${SERVICE_NAME}.history"
rollback_tag="${ROLLBACK_IMAGE_TAG:-${IMAGE_TAG:-}}"

if [[ -z "$rollback_tag" ]]; then
  [[ -f "$release_file" ]] || fail "Release history not found for $SERVICE_NAME: $release_file"

  successful_release_count=$(awk -F'|' -v service="$SERVICE_NAME" '$2 == service && $9 == "success" { count++ } END { print count + 0 }' "$release_file")
  if (( successful_release_count < 2 )); then
    fail "At least two successful releases are required for automatic N-1 rollback. Found: $successful_release_count"
  fi

  rollback_tag=$(awk -F'|' -v service="$SERVICE_NAME" '$2 == service && $9 == "success" { print $5 }' "$release_file" | tail -n 2 | head -n 1)
fi

[[ -n "$rollback_tag" ]] || fail "Rollback image tag could not be resolved."

if ! [[ "$rollback_tag" =~ ^[A-Za-z0-9_.-]+$ ]]; then
  fail "Rollback image tag contains unsupported characters: $rollback_tag"
fi

export IMAGE_TAG="$rollback_tag"

log "INFO" "Rollback target service: $SERVICE_NAME"
log "INFO" "Rollback target compose service: $COMPOSE_SERVICE"
log "INFO" "Rollback target image: ${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

if [[ "$SERVICE_NAME" == "contact" && "${RENDER_CONTACT_ENV_ON_ROLLBACK:-true}" == "true" ]]; then
  log "INFO" "Rendering contact runtime environment before contact rollback."
  "$SCRIPT_DIR/render-contact-env.sh"
fi

"$SCRIPT_DIR/deploy-service.sh"
"$SCRIPT_DIR/validate-service.sh"
"$SCRIPT_DIR/cleanup.sh"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf 'service=%s\n' "$SERVICE_NAME"
    printf 'compose_service=%s\n' "$COMPOSE_SERVICE"
    printf 'image_name=%s\n' "$IMAGE_NAME"
    printf 'image_tag=%s\n' "$IMAGE_TAG"
    printf 'image_ref=%s/%s:%s\n' "$DOCKERHUB_NAMESPACE" "$IMAGE_NAME" "$IMAGE_TAG"
  } >> "$GITHUB_OUTPUT"
fi

log "SUCCESS" "Rollback completed for $SERVICE_NAME using ${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}."
finish "SUCCESS"
