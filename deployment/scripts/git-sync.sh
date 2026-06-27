#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="Git Synchronization"

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

TARGET_BRANCH="${TARGET_BRANCH:-main}"

log "INFO" "START $STAGE"
log "INFO" "Synchronizing branch: $TARGET_BRANCH"

git fetch origin "$TARGET_BRANCH"
git checkout "$TARGET_BRANCH"
git reset --hard "origin/$TARGET_BRANCH"

if [[ -n "${EXPECTED_COMMIT:-}" ]]; then
  actual_commit=$(git rev-parse HEAD)
  expected_commit=$(git rev-parse "$EXPECTED_COMMIT")
  if [[ "$actual_commit" != "$expected_commit" ]]; then
    fail "HEAD is $actual_commit but expected $expected_commit. Refusing to deploy a different commit."
  fi
fi

log "SUCCESS" "Repository synchronized to $(git rev-parse --short=12 HEAD)."
finish "SUCCESS"
