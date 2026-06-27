#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Cleanup"

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

trap 'fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

for var in SERVICE_NAME IMAGE_NAME DOCKERHUB_NAMESPACE; do
  require_env "$var"
done

IMAGE_REPOSITORY="${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}"
release_file="deployment/releases/${SERVICE_NAME}.history"

declare -A keep_tags
keep_tags["latest"]=1
if [[ -f "$release_file" ]]; then
  while IFS='|' read -r _timestamp _service _compose _image tag _image_id _digest _run_id status; do
    [[ "$status" == "success" && -n "$tag" ]] || continue
    keep_tags["$tag"]=1
  done < <(awk -F'|' '$9=="success" {print}' "$release_file" | tail -n 2)
fi

if [[ -n "${IMAGE_TAG:-}" ]]; then
  keep_tags["$IMAGE_TAG"]=1
fi

log "INFO" "Keeping local tags for $IMAGE_REPOSITORY: ${!keep_tags[*]}"

docker images "$IMAGE_REPOSITORY" --format '{{.Repository}} {{.Tag}}' | while read -r repo tag; do
  [[ -z "$repo" || "$tag" == "<none>" ]] && continue
  if [[ -n "${keep_tags[$tag]:-}" ]]; then
    log "INFO" "Keeping $repo:$tag"
  else
    log "INFO" "Removing old local image $repo:$tag"
    docker rmi "$repo:$tag" || log "WARN" "Could not remove $repo:$tag; it may still be in use."
  fi
done

log "INFO" "Removing dangling images."
docker image prune -f >/dev/null || log "WARN" "Dangling image cleanup failed."

log "INFO" "Pruning build cache older than ${BUILD_CACHE_PRUNE_UNTIL:-24h}."
docker builder prune -f --filter "until=${BUILD_CACHE_PRUNE_UNTIL:-24h}" >/dev/null || log "WARN" "Build cache cleanup failed."

log "SUCCESS" "N-1 cleanup completed for $SERVICE_NAME."
finish "SUCCESS"
