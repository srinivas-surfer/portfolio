#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Image Validation"

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

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "Required environment variable is missing: $name"
}

docker_logout() {
  docker logout >/dev/null 2>&1 || true
}

trap 'docker_logout; fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

for var in IMAGE_NAME IMAGE_TAG DOCKERHUB_USERNAME DOCKERHUB_TOKEN DOCKERHUB_NAMESPACE; do
  require_env "$var"
done

IMAGE_REPOSITORY="${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}"
IMAGE_REF="${IMAGE_REPOSITORY}:${IMAGE_TAG}"

log "INFO" "Logging in to Docker Hub as $DOCKERHUB_USERNAME."
printf '%s' "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin >/dev/null
trap 'docker_logout' EXIT

log "INFO" "Pulling $IMAGE_REF for validation."
docker pull "$IMAGE_REF"

image_id=$(docker image inspect "$IMAGE_REF" --format '{{.Id}}')
revision_label=$(docker image inspect "$IMAGE_REF" --format '{{if .Config.Labels}}{{index .Config.Labels "org.opencontainers.image.revision"}}{{end}}')
repo_digest=$(docker image inspect "$IMAGE_REF" --format '{{range .RepoDigests}}{{println .}}{{end}}' | head -n 1)

[[ -n "$image_id" ]] || fail "Image ID is empty for $IMAGE_REF."
log "INFO" "Image ID: $image_id"

if [[ -n "$revision_label" && "$revision_label" != "<no value>" ]]; then
  log "INFO" "Image revision label: $revision_label"
else
  log "WARN" "Image revision label is missing."
fi

if [[ "${VALIDATE_IMAGE_STARTUP:-false}" == "true" ]]; then
  temp_name="validate-${IMAGE_NAME}-${IMAGE_TAG}-$$"
  log "INFO" "Starting temporary validation container $temp_name."
  docker run -d --name "$temp_name" "$IMAGE_REF" >/dev/null
  sleep "${VALIDATE_IMAGE_STARTUP_SECONDS:-3}"
  running_state=$(docker inspect "$temp_name" --format '{{.State.Running}}')
  docker rm -f "$temp_name" >/dev/null
  [[ "$running_state" == "true" ]] || fail "Temporary validation container did not stay running."
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf 'image_id=%s\n' "$image_id"
    printf 'image_digest=%s\n' "$repo_digest"
  } >> "$GITHUB_OUTPUT"
fi

docker_logout
trap - EXIT

log "SUCCESS" "Image validation passed for $IMAGE_REF."
finish "SUCCESS"
