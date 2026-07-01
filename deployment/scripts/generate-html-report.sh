#!/usr/bin/env bash
set -Eeuo pipefail

START_TIME=$(date +%s)
STAGE="HTML Report"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

trap 'fail "Unexpected failure at line $LINENO."' ERR

log "INFO" "START $STAGE"

ensure_docker_stack || fail "Docker/Compose bootstrap failed."

REPORT_BASE_URL="${REPORT_BASE_URL:-http://127.0.0.1}"
REPORT_BASE_URL="${REPORT_BASE_URL%/}"
REPORT_LOG_SINCE="${REPORT_LOG_SINCE:-24h}"
REPORT_LOG_TAIL_LINES="${REPORT_LOG_TAIL_LINES:-all}"
REPORT_LOG_ALERT_DETAIL_LIMIT="${REPORT_LOG_ALERT_DETAIL_LIMIT:-40}"
REPORT_LOG_ALERT_DETAIL_MAX_CHARS="${REPORT_LOG_ALERT_DETAIL_MAX_CHARS:-500}"
REPORT_PAGE_VIEW_LOG_SINCE="${REPORT_PAGE_VIEW_LOG_SINCE:-$REPORT_LOG_SINCE}"
REPORT_PAGE_VIEW_LOG_LINES="${REPORT_PAGE_VIEW_LOG_LINES:-all}"
REPORT_SERVICES="${REPORT_SERVICES:-portfolio,blog,projects,experience,contact}"
REPORT_OUTPUT="${REPORT_OUTPUT:-deployment/reports/platform-report-$(date -u +%Y%m%dT%H%M%SZ).html}"
REPORT_DISK_WARN_PERCENT="${REPORT_DISK_WARN_PERCENT:-80}"
REPORT_DISK_CRITICAL_PERCENT="${REPORT_DISK_CRITICAL_PERCENT:-90}"
REPORT_MEMORY_WARN_PERCENT="${REPORT_MEMORY_WARN_PERCENT:-80}"
REPORT_MEMORY_CRITICAL_PERCENT="${REPORT_MEMORY_CRITICAL_PERCENT:-90}"
REPORT_SWAP_WARN_PERCENT="${REPORT_SWAP_WARN_PERCENT:-50}"
REPORT_SWAP_CRITICAL_PERCENT="${REPORT_SWAP_CRITICAL_PERCENT:-80}"
REPORT_ROUTE_SLOW_SECONDS="${REPORT_ROUTE_SLOW_SECONDS:-2}"
REPORT_SSL_WARN_DAYS="${REPORT_SSL_WARN_DAYS:-30}"
REPORT_SSL_CRITICAL_DAYS="${REPORT_SSL_CRITICAL_DAYS:-7}"
DEPLOYMENT_STATE_DIR="${DEPLOYMENT_STATE_DIR:-deployment/releases}"

mkdir -p "$(dirname "$REPORT_OUTPUT")"

container_rows_file=$(mktemp /tmp/platform-report-containers.XXXXXX)
resource_rows_file=$(mktemp /tmp/platform-report-resources.XXXXXX)
route_rows_file=$(mktemp /tmp/platform-report-routes.XXXXXX)
endpoint_rows_file=$(mktemp /tmp/platform-report-endpoints.XXXXXX)
finding_rows_file=$(mktemp /tmp/platform-report-findings.XXXXXX)
deployment_rows_file=$(mktemp /tmp/platform-report-deployments.XXXXXX)
security_rows_file=$(mktemp /tmp/platform-report-security.XXXXXX)

cleanup_report_temp_files() {
  rm -f \
    "$container_rows_file" \
    "$resource_rows_file" \
    "$route_rows_file" \
    "$endpoint_rows_file" \
    "$finding_rows_file" \
    "$deployment_rows_file" \
    "$security_rows_file" \
    "${page_log_file:-}" \
    /tmp/platform-report-http.out \
    /tmp/platform-report-http.err
}

trap 'cleanup_report_temp_files; fail "Unexpected failure at line $LINENO."' ERR

health_score=100
warning_count=0
critical_count=0
total_services_count=0
running_services_count=0
healthy_containers_count=0
failed_routes_count=0
slow_routes_count=0
log_alert_total=0
rollback_ready_services_count=0
top_issue_severity=""
top_issue_text=""
route_duration_sum="0"
route_duration_count=0
slowest_route_label="n/a"
slowest_route_url="n/a"
slowest_route_status="n/a"
slowest_route_duration="n/a"
slowest_route_compare="-1"
fastest_route_label="n/a"
fastest_route_status="n/a"
fastest_route_duration="n/a"
fastest_route_compare="-1"
average_route_duration="n/a"
top_cpu_service="n/a"
top_cpu_container="n/a"
top_cpu_percent="n/a"
top_cpu_compare="-1"
top_memory_service="n/a"
top_memory_container="n/a"
top_memory_percent="n/a"
top_memory_compare="-1"
highest_restart_service="n/a"
highest_restart_container="n/a"
highest_restart_count=0

html_escape() {
  printf '%s' "$1" \
    | sed \
      -e 's/&/\&amp;/g' \
      -e 's/</\&lt;/g' \
      -e 's/>/\&gt;/g' \
      -e 's/"/\&quot;/g' \
      -e "s/'/\&#39;/g"
}

status_class() {
  case "$1" in
    running | healthy | 200 | expected-400 | ok) printf 'ok' ;;
    unhealthy | exited | dead | failed | critical | 000 | 4?? | 5??) printf 'bad' ;;
    missing | unknown | unavailable | warning) printf 'warn' ;;
    *) printf 'muted' ;;
  esac
}

emit() {
  printf '%s\n' "$*" >> "$REPORT_OUTPUT"
}

emit_row() {
  local cells=("$@")
  local cell

  emit "<tr>"
  for cell in "${cells[@]}"; do
    emit "<td>$(html_escape "$cell")</td>"
  done
  emit "</tr>"
}

emit_file_row() {
  local file="$1"
  shift

  local cells=("$@")
  local cell

  printf '%s\n' "<tr>" >> "$file"
  for cell in "${cells[@]}"; do
    printf '<td>%s</td>\n' "$(html_escape "$cell")" >> "$file"
  done
  printf '%s\n' "</tr>" >> "$file"
}

add_finding() {
  local severity="$1"
  local area="$2"
  local message="$3"
  local deduction="$4"

  if [[ "$severity" == "critical" ]]; then
    critical_count=$((critical_count + 1))
  else
    warning_count=$((warning_count + 1))
  fi

  if [[ -z "$top_issue_text" ]]; then
    top_issue_severity="$severity"
    top_issue_text="${area}: ${message}"
  elif [[ "$severity" == "critical" && "$top_issue_severity" != "critical" ]]; then
    top_issue_severity="$severity"
    top_issue_text="${area}: ${message}"
  fi

  if [[ "$deduction" =~ ^[0-9]+$ ]]; then
    health_score=$((health_score - deduction))
  fi

  printf '<tr><td><span class="pill %s">%s</span></td><td>%s</td><td>%s</td><td>%s</td></tr>\n' \
    "$(status_class "$severity")" \
    "$(html_escape "$severity")" \
    "$(html_escape "$area")" \
    "$(html_escape "$message")" \
    "$(html_escape "-${deduction}")" >> "$finding_rows_file"
}

finalize_health_score() {
  if (( health_score < 0 )); then
    health_score=0
  elif (( health_score > 100 )); then
    health_score=100
  fi
}

server_status() {
  if (( critical_count > 0 || health_score < 70 )); then
    printf 'Critical'
  elif (( warning_count > 0 || health_score < 90 )); then
    printf 'Warning'
  else
    printf 'Healthy'
  fi
}

server_status_class() {
  case "$(server_status)" in
    Healthy) printf 'ok' ;;
    Warning) printf 'warn' ;;
    *) printf 'bad' ;;
  esac
}

numeric_ge() {
  awk -v left="$1" -v right="$2" 'BEGIN { exit !(left >= right) }'
}

numeric_gt() {
  awk -v left="$1" -v right="$2" 'BEGIN { exit !(left > right) }'
}

percent_number() {
  printf '%s' "$1" | tr -d '%' | awk '{ printf "%.0f", $1 }'
}

percent_float() {
  printf '%s' "$1" | tr -d '%' | awk '
    $1 ~ /^[0-9]+([.][0-9]+)?$/ { printf "%.4f", $1; next }
    { printf "0" }
  '
}

image_tag_from_ref() {
  local image="$1"

  if [[ "$image" == *@* ]]; then
    printf 'digest-only'
  elif [[ "$image" == *:* ]]; then
    printf '%s' "${image##*:}"
  elif [[ -n "$image" && "$image" != "missing" && "$image" != "unavailable" ]]; then
    printf 'latest'
  else
    printf 'n/a'
  fi
}

iso_to_epoch() {
  local value="$1"
  local normalized

  [[ -n "$value" && "$value" != "missing" && "$value" != "unavailable" ]] || {
    printf ''
    return 0
  }

  normalized="$value"
  if [[ "$normalized" == *.* ]]; then
    normalized="${normalized%%.*}Z"
  fi

  date -d "$normalized" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$normalized" +%s 2>/dev/null || true
}

human_duration() {
  local seconds="$1"
  local days hours minutes

  [[ "$seconds" =~ ^[0-9]+$ ]] || {
    printf 'n/a'
    return
  }

  days=$((seconds / 86400))
  hours=$(((seconds % 86400) / 3600))
  minutes=$(((seconds % 3600) / 60))

  if (( days > 0 )); then
    printf '%sd %sh' "$days" "$hours"
  elif (( hours > 0 )); then
    printf '%sh %sm' "$hours" "$minutes"
  else
    printf '%sm' "$minutes"
  fi
}

age_since() {
  local timestamp="$1"
  local epoch now diff

  epoch=$(iso_to_epoch "$timestamp")
  [[ -n "$epoch" ]] || {
    printf 'n/a'
    return
  }

  now=$(date +%s)
  diff=$((now - epoch))
  (( diff < 0 )) && diff=0
  human_duration "$diff"
}

base_domain() {
  local value="$1"
  value="${value#http://}"
  value="${value#https://}"
  value="${value%%/*}"
  value="${value%%:*}"
  printf '%s' "$value"
}

resolve_dns() {
  local host="$1"

  if command -v getent >/dev/null 2>&1; then
    getent hosts "$host" | awk '{print $1}' | sort -u | paste -sd ', ' -
    return
  fi

  if command -v dig >/dev/null 2>&1; then
    dig +short "$host" | paste -sd ', ' -
    return
  fi

  if command -v nslookup >/dev/null 2>&1; then
    nslookup "$host" 2>/dev/null | awk '/^Address: / {print $2}' | paste -sd ', ' -
    return
  fi

  printf 'unavailable'
}

ssl_days_remaining() {
  local host="$1"
  local expiry expiry_epoch now_epoch

  command -v openssl >/dev/null 2>&1 || {
    printf 'unavailable'
    return
  }

  expiry=$(echo | openssl s_client -servername "$host" -connect "${host}:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | sed 's/^notAfter=//') || true
  [[ -n "$expiry" ]] || {
    printf 'unavailable'
    return
  }

  expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %e %T %Y %Z" "$expiry" +%s 2>/dev/null || true)
  [[ -n "$expiry_epoch" ]] || {
    printf 'unavailable'
    return
  }

  now_epoch=$(date +%s)
  printf '%s' $(((expiry_epoch - now_epoch) / 86400))
}

container_value() {
  local container="$1"
  local template="$2"
  local fallback="${3:-unavailable}"

  docker inspect "$container" --format "$template" 2>/dev/null || printf '%s' "$fallback"
}

container_health() {
  local container="$1"

  docker inspect "$container" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' 2>/dev/null || printf 'missing'
}

container_ports() {
  local container="$1"
  local ports

  ports=$(docker port "$container" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//') || true
  [[ -n "$ports" ]] && printf '%s' "$ports" || printf 'none'
}

container_image_digest() {
  local image="$1"
  local digest

  digest=$(docker image inspect "$image" --format '{{range .RepoDigests}}{{println .}}{{end}}' 2>/dev/null | head -n 1 || true)
  [[ -n "$digest" ]] && printf '%s' "$digest" || printf 'n/a'
}

container_stats() {
  local container="$1"
  local stats

  stats=$(docker stats --no-stream --format '{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.NetIO}}' "$container" 2>/dev/null || true)
  [[ -n "$stats" ]] && printf '%s' "$stats" || printf 'n/a|n/a|n/a|n/a'
}

update_resource_leaders() {
  local service="$1"
  local container="$2"
  local cpu_percent="$3"
  local memory_percent="$4"
  local restart_count="$5"
  local cpu_value memory_value

  cpu_value=$(percent_float "$cpu_percent")
  memory_value=$(percent_float "$memory_percent")

  if [[ "$top_cpu_compare" == "-1" ]] || numeric_gt "$cpu_value" "$top_cpu_compare"; then
    top_cpu_compare="$cpu_value"
    top_cpu_service="$service"
    top_cpu_container="$container"
    top_cpu_percent="$cpu_percent"
  fi

  if [[ "$top_memory_compare" == "-1" ]] || numeric_gt "$memory_value" "$top_memory_compare"; then
    top_memory_compare="$memory_value"
    top_memory_service="$service"
    top_memory_container="$container"
    top_memory_percent="$memory_percent"
  fi

  if [[ "$restart_count" =~ ^[0-9]+$ && ( "$highest_restart_service" == "n/a" || "$restart_count" -gt "$highest_restart_count" ) ]]; then
    highest_restart_count="$restart_count"
    highest_restart_service="$service"
    highest_restart_container="$container"
  fi
}

collect_container_report() {
  local service state health image started ports alerts state_css health_css
  local restart_count digest stats cpu_percent memory_usage memory_percent net_io cpu_number memory_number

  IFS=',' read -r -a report_services <<< "$REPORT_SERVICES"
  for service in "${report_services[@]}"; do
    service="${service//[[:space:]]/}"
    [[ -z "$service" ]] && continue

    total_services_count=$((total_services_count + 1))
    set_service_context "$service"

    if docker ps -aq -f "name=^/${CONTAINER_NAME}$" | grep -q .; then
      state=$(container_value "$CONTAINER_NAME" '{{.State.Status}}')
      health=$(container_health "$CONTAINER_NAME")
      image=$(container_value "$CONTAINER_NAME" '{{.Config.Image}}')
      started=$(container_value "$CONTAINER_NAME" '{{.State.StartedAt}}')
      ports=$(container_ports "$CONTAINER_NAME")
      alerts=$(service_error_count "$CONTAINER_NAME")
      restart_count=$(container_value "$CONTAINER_NAME" '{{.RestartCount}}' '0')
      digest=$(container_image_digest "$image")
      stats=$(container_stats "$CONTAINER_NAME")
      IFS='|' read -r cpu_percent memory_usage memory_percent net_io <<< "$stats"
      update_resource_leaders "$SERVICE_NAME" "$CONTAINER_NAME" "$cpu_percent" "$memory_percent" "$restart_count"

      [[ "$state" == "running" ]] && running_services_count=$((running_services_count + 1))
      [[ "$health" == "healthy" || "$health" == "none" ]] && healthy_containers_count=$((healthy_containers_count + 1))

      if [[ "$state" != "running" ]]; then
        add_finding "critical" "$SERVICE_NAME" "Container is not running: $state" 20
      fi

      if [[ "$health" == "unhealthy" ]]; then
        add_finding "critical" "$SERVICE_NAME" "Container healthcheck is unhealthy." 15
      elif [[ "$health" != "healthy" && "$health" != "none" ]]; then
        add_finding "warning" "$SERVICE_NAME" "Container healthcheck status is $health." 5
      fi

      if [[ "$restart_count" =~ ^[0-9]+$ && "$restart_count" -gt 0 ]]; then
        if [[ "$restart_count" -gt 3 ]]; then
          add_finding "warning" "$SERVICE_NAME" "Container restart count is $restart_count." 5
        else
          add_finding "warning" "$SERVICE_NAME" "Container restart count is $restart_count." 2
        fi
      fi

      if [[ "$alerts" =~ ^[0-9]+$ && "$alerts" -gt 0 ]]; then
        log_alert_total=$((log_alert_total + alerts))
        if [[ "$alerts" -gt 10 ]]; then
          add_finding "critical" "$SERVICE_NAME" "High log alert count in report window: $alerts." 10
        else
          add_finding "warning" "$SERVICE_NAME" "Log alert count in report window: $alerts." 2
        fi
      fi

      cpu_number=$(percent_number "$cpu_percent")
      memory_number=$(percent_number "$memory_percent")
      if [[ "$cpu_number" =~ ^[0-9]+$ ]] && (( cpu_number >= 80 )); then
        add_finding "warning" "$SERVICE_NAME" "Container CPU usage is ${cpu_percent}." 5
      fi
      if [[ "$memory_number" =~ ^[0-9]+$ ]] && (( memory_number >= 80 )); then
        add_finding "warning" "$SERVICE_NAME" "Container memory usage is ${memory_percent}." 5
      fi
    else
      state="missing"
      health="missing"
      image="missing"
      started="missing"
      ports="none"
      alerts="0"
      restart_count="n/a"
      digest="n/a"
      cpu_percent="n/a"
      memory_usage="n/a"
      memory_percent="n/a"
      net_io="n/a"
      add_finding "critical" "$SERVICE_NAME" "Container is missing." 20
    fi

    state_css=$(status_class "$state")
    health_css=$(status_class "$health")
    printf '<tr><td>%s</td><td>%s</td><td><span class="pill %s">%s</span></td><td><span class="pill %s">%s</span></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n' \
      "$(html_escape "$SERVICE_NAME")" \
      "$(html_escape "$CONTAINER_NAME")" \
      "$state_css" \
      "$(html_escape "$state")" \
      "$health_css" \
      "$(html_escape "$health")" \
      "$(html_escape "$image")" \
      "$(html_escape "$ports")" \
      "$(html_escape "$started")" \
      "$(html_escape "$alerts")" >> "$container_rows_file"

    emit_file_row "$resource_rows_file" "$SERVICE_NAME" "$CONTAINER_NAME" "$cpu_percent" "$memory_usage" "$memory_percent" "$net_io" "$restart_count" "$digest"
  done
}

collect_deployment_report() {
  local service release_file success_count current_image current_tag current_digest started deployment_age
  local previous_tag last_release_time rollback_status rollback_css history_status

  IFS=',' read -r -a report_services <<< "$REPORT_SERVICES"
  for service in "${report_services[@]}"; do
    service="${service//[[:space:]]/}"
    [[ -z "$service" ]] && continue

    set_service_context "$service"
    release_file="${DEPLOYMENT_STATE_DIR}/${SERVICE_NAME}.history"
    success_count="0"
    previous_tag="n/a"
    last_release_time="n/a"
    rollback_status="not ready"
    rollback_css="warn"
    history_status="missing"

    if docker ps -aq -f "name=^/${CONTAINER_NAME}$" | grep -q .; then
      current_image=$(container_value "$CONTAINER_NAME" '{{.Config.Image}}')
      current_tag=$(image_tag_from_ref "$current_image")
      current_digest=$(container_image_digest "$current_image")
      started=$(container_value "$CONTAINER_NAME" '{{.State.StartedAt}}')
      deployment_age=$(age_since "$started")
    else
      current_image="missing"
      current_tag="n/a"
      current_digest="n/a"
      deployment_age="n/a"
    fi

    if [[ -f "$release_file" ]]; then
      success_count=$(awk -F'|' -v service="$SERVICE_NAME" '$2 == service && $9 == "success" { count++ } END { print count + 0 }' "$release_file")
      last_release_time=$(awk -F'|' -v service="$SERVICE_NAME" '$2 == service && $9 == "success" { print $1 }' "$release_file" | tail -n 1)
      [[ -n "$last_release_time" ]] || last_release_time="n/a"
      history_status="${success_count} successful release(s)"

      if [[ "$success_count" =~ ^[0-9]+$ && "$success_count" -ge 2 ]]; then
        previous_tag=$(awk -F'|' -v service="$SERVICE_NAME" '$2 == service && $9 == "success" { print $5 }' "$release_file" | tail -n 2 | head -n 1)
        [[ -n "$previous_tag" ]] || previous_tag="n/a"
        rollback_status="ready"
        rollback_css="ok"
        rollback_ready_services_count=$((rollback_ready_services_count + 1))
      elif [[ "$success_count" =~ ^[0-9]+$ && "$success_count" -eq 1 ]]; then
        rollback_status="needs N-1"
        add_finding "warning" "$SERVICE_NAME" "Rollback readiness has only one successful release recorded." 4
      else
        rollback_status="missing history"
        add_finding "warning" "$SERVICE_NAME" "Rollback release history is missing or empty." 4
      fi
    else
      add_finding "warning" "$SERVICE_NAME" "Rollback release history file is missing: $release_file" 4
    fi

    printf '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td><span class="pill %s">%s</span></td><td>%s</td></tr>\n' \
      "$(html_escape "$SERVICE_NAME")" \
      "$(html_escape "$current_tag")" \
      "$(html_escape "$current_digest")" \
      "$(html_escape "$deployment_age")" \
      "$(html_escape "$previous_tag")" \
      "$rollback_css" \
      "$(html_escape "$rollback_status")" \
      "$(html_escape "$history_status; last success: $last_release_time")" >> "$deployment_rows_file"
  done
}

collect_security_snapshot() {
  local service ports privileged readonly_rootfs configured_user user_display socket_mount sensitive_env_count
  local status status_css notes

  IFS=',' read -r -a report_services <<< "$REPORT_SERVICES"
  for service in "${report_services[@]}"; do
    service="${service//[[:space:]]/}"
    [[ -z "$service" ]] && continue

    set_service_context "$service"

    if ! docker ps -aq -f "name=^/${CONTAINER_NAME}$" | grep -q .; then
      printf '<tr><td>%s</td><td>missing</td><td>missing</td><td>missing</td><td>missing</td><td>missing</td><td>missing</td><td><span class="pill bad">critical</span> Container missing.</td></tr>\n' \
        "$(html_escape "$SERVICE_NAME")" >> "$security_rows_file"
      continue
    fi

    ports=$(container_ports "$CONTAINER_NAME")
    privileged=$(container_value "$CONTAINER_NAME" '{{.HostConfig.Privileged}}' 'unknown')
    readonly_rootfs=$(container_value "$CONTAINER_NAME" '{{.HostConfig.ReadonlyRootfs}}' 'unknown')
    configured_user=$(container_value "$CONTAINER_NAME" '{{.Config.User}}' '')
    [[ -n "$configured_user" ]] && user_display="$configured_user" || user_display="image default"
    socket_mount="no"
    sensitive_env_count=$(docker inspect "$CONTAINER_NAME" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null \
      | awk -F= '{print $1}' \
      | grep -Eic 'PASS|PASSWORD|TOKEN|SECRET|KEY|AUTH|SMTP|SES' || true)

    if docker inspect "$CONTAINER_NAME" --format '{{range .Mounts}}{{println .Source "|" .Destination}}{{end}}' 2>/dev/null \
      | grep -Eq '(^|[|[:space:]])/var/run/docker.sock($|[|[:space:]])|docker.sock'; then
      socket_mount="yes"
    fi

    status="ok"
    status_css="ok"
    notes="Baseline runtime posture."

    if [[ "$user_display" == "image default" ]]; then
      notes="${notes} User is image default; review root behavior."
      [[ "$status" == "ok" ]] && { status="review"; status_css="warn"; }
    fi

    if [[ "$readonly_rootfs" == "false" ]]; then
      notes="${notes} Root filesystem is writable."
      [[ "$status" == "ok" ]] && { status="review"; status_css="warn"; }
    fi

    if [[ "$sensitive_env_count" =~ ^[0-9]+$ && "$sensitive_env_count" -gt 0 ]]; then
      notes="${notes} ${sensitive_env_count} sensitive-looking environment variable name(s) present."
      [[ "$status" == "ok" ]] && { status="review"; status_css="warn"; }
    fi

    if [[ "$ports" != "none" && "$SERVICE_NAME" != "portfolio" ]]; then
      status="warning"
      status_css="warn"
      notes="${notes} Unexpected host port binding for private service."
      add_finding "warning" "$SERVICE_NAME" "Private service has host port binding: $ports" 5
    elif [[ "$ports" != "none" ]]; then
      notes="${notes} Host port binding is expected for the public entrypoint."
    fi

    if [[ "$privileged" == "true" ]]; then
      status="critical"
      status_css="bad"
      notes="${notes} Container is privileged."
      add_finding "critical" "$SERVICE_NAME" "Container is running in privileged mode." 15
    fi

    if [[ "$socket_mount" == "yes" ]]; then
      status="critical"
      status_css="bad"
      notes="${notes} Docker socket is mounted."
      add_finding "critical" "$SERVICE_NAME" "Container has Docker socket access." 15
    fi

    printf '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td><span class="pill %s">%s</span> %s</td></tr>\n' \
      "$(html_escape "$SERVICE_NAME")" \
      "$(html_escape "$ports")" \
      "$(html_escape "$privileged")" \
      "$(html_escape "$socket_mount")" \
      "$(html_escape "$user_display")" \
      "$(html_escape "$readonly_rootfs")" \
      "$(html_escape "$sensitive_env_count")" \
      "$status_css" \
      "$(html_escape "$status")" \
      "$(html_escape "$notes")" >> "$security_rows_file"
  done
}

service_error_count() {
  local container="$1"

  if ! docker ps -aq -f "name=^/${container}$" | grep -q .; then
    printf '0'
    return
  fi

  docker_logs_window "$container" "$REPORT_LOG_TAIL_LINES" "$REPORT_LOG_SINCE" 2>&1 \
    | grep -Eic 'error|warn|fail|exception|unhealthy' || true
}

docker_logs_window() {
  local container="$1"
  local tail_lines="$2"
  local since_window="${3:-}"
  local -a log_args=()

  if [[ -n "$since_window" ]]; then
    log_args+=(--since "$since_window")
  fi

  if [[ -n "$tail_lines" ]]; then
    log_args+=(--tail "$tail_lines")
  fi

  docker logs "${log_args[@]}" "$container"
}

window_description() {
  local since_window="$1"
  local tail_lines="$2"

  if [[ -n "$since_window" ]]; then
    printf 'since %s, tail %s' "$since_window" "$tail_lines"
  else
    printf 'last %s lines' "$tail_lines"
  fi
}

collect_infrastructure_report() {
  cpu_cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || printf 'unknown')
  load_average=$(awk '{print $1" "$2" "$3}' /proc/loadavg 2>/dev/null || uptime | sed 's/^.*load averages*: //' 2>/dev/null || printf 'unknown')
  load_1m=$(printf '%s' "$load_average" | awk '{print $1}')
  uptime_text=$(uptime -p 2>/dev/null || uptime 2>/dev/null || printf 'unknown')
  disk_use_percent=$(df -P . | awk 'NR == 2 {gsub("%", "", $5); print $5}')
  disk_summary=$(df -h . | awk 'NR == 2 { print "size=" $2 ", used=" $3 ", available=" $4 ", use=" $5 }')
  memory_summary="unavailable"
  memory_use_percent="unknown"
  swap_use_percent="unknown"
  network_summary="unavailable"

  if [[ -r /proc/meminfo ]]; then
    read -r memory_summary memory_use_percent swap_use_percent < <(awk '
      /MemTotal/ { mem_total = int($2 / 1024) }
      /MemAvailable/ { mem_available = int($2 / 1024) }
      /SwapTotal/ { swap_total = int($2 / 1024) }
      /SwapFree/ { swap_free = int($2 / 1024) }
      END {
        mem_used = mem_total - mem_available
        mem_percent = mem_total > 0 ? int(mem_used * 100 / mem_total) : 0
        swap_used = swap_total - swap_free
        swap_percent = swap_total > 0 ? int(swap_used * 100 / swap_total) : 0
        summary = "memory_total=" mem_total "MB,memory_available=" mem_available "MB,swap_total=" swap_total "MB,swap_free=" swap_free "MB"
        print summary, mem_percent, swap_percent
      }
    ' /proc/meminfo)
    memory_summary="${memory_summary//,/ }"
  elif command -v vm_stat >/dev/null 2>&1; then
    memory_summary=$(vm_stat | tr '\n' ' ' | sed 's/[[:space:]]*$//')
  fi

  if [[ -r /proc/net/dev ]]; then
    network_summary=$(awk -F'[: ]+' '
      NR > 2 && $2 != "lo" {
        rx += $3
        tx += $11
      }
      END {
        printf "rx=%.2fMB, tx=%.2fMB", rx / 1024 / 1024, tx / 1024 / 1024
      }
    ' /proc/net/dev)
  fi

  if [[ "$disk_use_percent" =~ ^[0-9]+$ ]]; then
    if (( disk_use_percent >= REPORT_DISK_CRITICAL_PERCENT )); then
      add_finding "critical" "Infrastructure" "Disk usage is ${disk_use_percent}%." 15
    elif (( disk_use_percent >= REPORT_DISK_WARN_PERCENT )); then
      add_finding "warning" "Infrastructure" "Disk usage is ${disk_use_percent}%." 5
    fi
  fi

  if [[ "$memory_use_percent" =~ ^[0-9]+$ ]]; then
    if (( memory_use_percent >= REPORT_MEMORY_CRITICAL_PERCENT )); then
      add_finding "critical" "Infrastructure" "Memory usage is ${memory_use_percent}%." 15
    elif (( memory_use_percent >= REPORT_MEMORY_WARN_PERCENT )); then
      add_finding "warning" "Infrastructure" "Memory usage is ${memory_use_percent}%." 5
    fi
  fi

  if [[ "$swap_use_percent" =~ ^[0-9]+$ ]]; then
    if (( swap_use_percent >= REPORT_SWAP_CRITICAL_PERCENT )); then
      add_finding "critical" "Infrastructure" "Swap usage is ${swap_use_percent}%." 10
    elif (( swap_use_percent >= REPORT_SWAP_WARN_PERCENT )); then
      add_finding "warning" "Infrastructure" "Swap usage is ${swap_use_percent}%." 3
    fi
  fi

  if [[ "$cpu_cores" =~ ^[0-9]+$ && "$load_1m" != "unknown" ]]; then
    if numeric_gt "$load_1m" "$((cpu_cores * 2))"; then
      add_finding "critical" "Infrastructure" "1-minute load average ${load_1m} is above 2x CPU cores (${cpu_cores})." 10
    elif numeric_gt "$load_1m" "$cpu_cores"; then
      add_finding "warning" "Infrastructure" "1-minute load average ${load_1m} is above CPU cores (${cpu_cores})." 5
    fi
  fi
}

collect_public_endpoint_report() {
  public_host=$(base_domain "$REPORT_BASE_URL")
  dns_result=$(resolve_dns "$public_host")
  ssl_remaining="not-applicable"

  if [[ -z "$dns_result" || "$dns_result" == "unavailable" ]]; then
    add_finding "critical" "Public Endpoint" "DNS resolution failed for $public_host." 10
    dns_status="failed"
  else
    dns_status="ok"
  fi

  emit_file_row "$endpoint_rows_file" "DNS Resolution" "$public_host" "$dns_status" "$dns_result"

  if [[ "$REPORT_BASE_URL" == https://* ]]; then
    ssl_remaining=$(ssl_days_remaining "$public_host")
    if [[ "$ssl_remaining" =~ ^-?[0-9]+$ ]]; then
      if (( ssl_remaining <= REPORT_SSL_CRITICAL_DAYS )); then
        add_finding "critical" "Public Endpoint" "TLS certificate expires in ${ssl_remaining} day(s)." 10
        ssl_status="critical"
      elif (( ssl_remaining <= REPORT_SSL_WARN_DAYS )); then
        add_finding "warning" "Public Endpoint" "TLS certificate expires in ${ssl_remaining} day(s)." 5
        ssl_status="warning"
      else
        ssl_status="ok"
      fi
      emit_file_row "$endpoint_rows_file" "TLS Certificate" "$public_host" "$ssl_status" "${ssl_remaining} day(s) remaining"
    else
      add_finding "warning" "Public Endpoint" "Could not determine TLS certificate expiry for $public_host." 5
      emit_file_row "$endpoint_rows_file" "TLS Certificate" "$public_host" "unavailable" "$ssl_remaining"
    fi
  else
    emit_file_row "$endpoint_rows_file" "TLS Certificate" "$public_host" "not-applicable" "Base URL is not HTTPS"
  fi
}

extract_alert_keyword() {
  local line="$1"
  local keyword

  keyword=$(printf '%s\n' "$line" | grep -Eio 'error|warn|fail|exception|unhealthy' | head -n 1 || true)
  [[ -n "$keyword" ]] && printf '%s' "$keyword" || printf 'alert'
}

extract_log_error_code() {
  local line="$1"
  local code

  code=$(printf '%s\n' "$line" | sed -nE 's/.*responseCode[^0-9]*([0-9]{3}).*/SMTP \1/p' | head -n 1)
  [[ -n "$code" ]] && { printf '%s' "$code"; return; }

  code=$(printf '%s\n' "$line" | sed -nE 's/.*"status":"?([45][0-9][0-9])"?.*/HTTP \1/p' | head -n 1)
  [[ -n "$code" ]] && { printf '%s' "$code"; return; }

  code=$(printf '%s\n' "$line" | sed -nE 's/.*HTTP\/[0-9.]+"[[:space:]]+([45][0-9][0-9]).*/HTTP \1/p' | head -n 1)
  [[ -n "$code" ]] && { printf '%s' "$code"; return; }

  code=$(printf '%s\n' "$line" | sed -nE "s/.*code[[:space:]]*[:=][[:space:]]*'?([A-Za-z0-9_-]+)'?.*/\1/p" | head -n 1)
  [[ -n "$code" ]] && { printf '%s' "$code"; return; }

  printf 'n/a'
}

sanitize_log_line() {
  printf '%s' "$1" \
    | sed -E \
      -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/[email]/g' \
      -e 's/([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Pp][Aa][Ss][Ss]|[Tt][Oo][Kk][Ee][Nn]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Aa][Uu][Tt][Hh][Oo][Rr][Ii][Zz][Aa][Tt][Ii][Oo][Nn])[^ ,;}"]*/\1=[redacted]/g'
}

truncate_text() {
  local text="$1"
  local max_chars="$2"

  if (( ${#text} > max_chars )); then
    printf '%s...' "${text:0:max_chars}"
  else
    printf '%s' "$text"
  fi
}

emit_log_alert_details() {
  local details_written=0
  local truncated="false"
  local service alert_line keyword code sanitized snippet
  local -a detail_services
  local detail_window

  detail_window=$(window_description "$REPORT_LOG_SINCE" "$REPORT_LOG_TAIL_LINES")
  emit "<h2>Ongoing Log Alert Details</h2>"
  emit "<p class=\"meta\">Recent alert-like log lines from Docker logs ($(html_escape "$detail_window")). Details are capped at $(html_escape "$REPORT_LOG_ALERT_DETAIL_LIMIT") rows and sanitized before rendering.</p>"
  emit "<table><thead><tr><th>Service</th><th>Container</th><th>Matched Keyword</th><th>Error Code</th><th>Log Detail</th></tr></thead><tbody>"

  IFS=',' read -r -a detail_services <<< "$REPORT_SERVICES"
  for service in "${detail_services[@]}"; do
    service="${service//[[:space:]]/}"
    [[ -z "$service" ]] && continue

    set_service_context "$service"
    if ! docker ps -aq -f "name=^/${CONTAINER_NAME}$" | grep -q .; then
      continue
    fi

    while IFS= read -r alert_line; do
      [[ -z "$alert_line" ]] && continue

      if (( details_written >= REPORT_LOG_ALERT_DETAIL_LIMIT )); then
        truncated="true"
        break 2
      fi

      keyword=$(extract_alert_keyword "$alert_line")
      code=$(extract_log_error_code "$alert_line")
      sanitized=$(sanitize_log_line "$alert_line")
      snippet=$(truncate_text "$sanitized" "$REPORT_LOG_ALERT_DETAIL_MAX_CHARS")

      emit "<tr><td>$(html_escape "$SERVICE_NAME")</td><td>$(html_escape "$CONTAINER_NAME")</td><td>$(html_escape "$keyword")</td><td>$(html_escape "$code")</td><td class=\"log-line\">$(html_escape "$snippet")</td></tr>"
      details_written=$((details_written + 1))
    done < <(docker_logs_window "$CONTAINER_NAME" "$REPORT_LOG_TAIL_LINES" "$REPORT_LOG_SINCE" 2>&1 | grep -Ei 'error|warn|fail|exception|unhealthy' || true)
  done

  if (( details_written == 0 )); then
    emit "<tr><td colspan=\"5\">No matching log alert details found in the scanned window.</td></tr>"
  elif [[ "$truncated" == "true" ]]; then
    emit "<tr><td colspan=\"5\">Additional matching log lines were found but omitted because the detail limit was reached.</td></tr>"
  fi

  emit "</tbody></table>"
}

update_route_performance() {
  local label="$1"
  local url="$2"
  local status="$3"
  local duration="$4"

  [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 0

  route_duration_count=$((route_duration_count + 1))
  route_duration_sum=$(awk -v sum="$route_duration_sum" -v value="$duration" 'BEGIN { printf "%.6f", sum + value }')

  if [[ "$slowest_route_compare" == "-1" ]] || numeric_gt "$duration" "$slowest_route_compare"; then
    slowest_route_compare="$duration"
    slowest_route_label="$label"
    slowest_route_url="$url"
    slowest_route_status="$status"
    slowest_route_duration="$duration"
  fi

  if [[ "$fastest_route_compare" == "-1" ]] || numeric_gt "$fastest_route_compare" "$duration"; then
    fastest_route_compare="$duration"
    fastest_route_label="$label"
    fastest_route_status="$status"
    fastest_route_duration="$duration"
  fi
}

finalize_performance_summary() {
  if (( route_duration_count > 0 )); then
    average_route_duration=$(awk -v sum="$route_duration_sum" -v count="$route_duration_count" 'BEGIN { printf "%.3f", sum / count }')
  fi
}

http_check() {
  local label="$1"
  local path="$2"
  local url="${REPORT_BASE_URL}${path}"
  local result status duration bytes css healthy_status

  if ! command -v curl >/dev/null 2>&1; then
    emit_file_row "$route_rows_file" "$label" "$url" "curl missing" "unavailable" "unavailable"
    failed_routes_count=$((failed_routes_count + 1))
    add_finding "critical" "Application Route" "curl is missing; could not check $url." 10
    return
  fi

  result=$(curl -sS -A "Portfolio-Report-HealthCheck" -o /tmp/platform-report-http.out -w '%{http_code}|%{time_total}|%{size_download}' "$url" 2>/tmp/platform-report-http.err || true)
  status="${result%%|*}"
  result="${result#*|}"
  duration="${result%%|*}"
  bytes="${result#*|}"
  [[ -n "$status" ]] || status="failed"
  css=$(status_class "$status")
  healthy_status="false"

  if [[ "$status" =~ ^2[0-9][0-9]$ || "$status" =~ ^3[0-9][0-9]$ ]]; then
    healthy_status="true"
  fi

  if [[ "$healthy_status" != "true" ]]; then
    failed_routes_count=$((failed_routes_count + 1))
    add_finding "critical" "Application Route" "$url returned $status." 12
  fi

  if [[ "$duration" =~ ^[0-9.]+$ ]] && numeric_gt "$duration" "$REPORT_ROUTE_SLOW_SECONDS"; then
    slow_routes_count=$((slow_routes_count + 1))
    add_finding "warning" "Application Route" "$url responded slowly in ${duration}s." 3
  fi

  update_route_performance "$label" "$url" "$status" "$duration"

  printf '<tr><td>%s</td><td>%s</td><td><span class="pill %s">%s</span></td><td>%s</td><td>%s</td></tr>\n' \
    "$(html_escape "$label")" \
    "$(html_escape "$url")" \
    "$css" \
    "$(html_escape "$status")" \
    "$(html_escape "$duration")" \
    "$(html_escape "$bytes")" >> "$route_rows_file"
}

contact_contract_check() {
  local label="Contact API Contract"
  local url="${REPORT_BASE_URL}/api/contact"
  local result status duration bytes display_status css

  if ! command -v curl >/dev/null 2>&1; then
    emit_file_row "$route_rows_file" "$label" "$url" "curl missing" "unavailable" "unavailable"
    failed_routes_count=$((failed_routes_count + 1))
    add_finding "critical" "Application Route" "curl is missing; could not check $url." 10
    return
  fi

  result=$(curl -sS -A "Portfolio-Report-HealthCheck" -o /tmp/platform-report-http.out -w '%{http_code}|%{time_total}|%{size_download}' \
    -X POST "$url" \
    -H "Content-Type: application/json" \
    -d '{}' 2>/tmp/platform-report-http.err || true)
  status="${result%%|*}"
  result="${result#*|}"
  duration="${result%%|*}"
  bytes="${result#*|}"
  [[ -n "$status" ]] || status="failed"

  if [[ "$status" == "400" ]] && grep -q "Missing required fields" /tmp/platform-report-http.out 2>/dev/null; then
    display_status="expected-400"
  else
    display_status="$status"
    failed_routes_count=$((failed_routes_count + 1))
    add_finding "critical" "Application Route" "$url contract check returned $status." 12
  fi

  if [[ "$duration" =~ ^[0-9.]+$ ]] && numeric_gt "$duration" "$REPORT_ROUTE_SLOW_SECONDS"; then
    slow_routes_count=$((slow_routes_count + 1))
    add_finding "warning" "Application Route" "$url responded slowly in ${duration}s." 3
  fi

  css=$(status_class "$display_status")
  update_route_performance "$label" "$url" "$display_status" "$duration"
  printf '<tr><td>%s</td><td>%s</td><td><span class="pill %s">%s</span></td><td>%s</td><td>%s</td></tr>\n' \
    "$(html_escape "$label")" \
    "$(html_escape "$url")" \
    "$css" \
    "$(html_escape "$display_status")" \
    "$(html_escape "$duration")" \
    "$(html_escape "$bytes")" >> "$route_rows_file"
}

collect_route_report() {
  http_check "Home" "/"
  http_check "Blog" "/blog/"
  http_check "Projects" "/projects/"
  http_check "Experience" "/experience/"
  http_check "Contact Page" "/contact.html"
  contact_contract_check
}

count_logged_path() {
  local mode="$1"
  local pattern="$2"
  local log_file="$3"

  awk '
    /Portfolio-Report-HealthCheck|Wget|curl|HealthCheck|kube-probe/ { next }
    /"request_uri":"[^"]+"/ {
      line = $0
      sub(/^.*"request_uri":"/, "", line)
      sub(/".*$/, "", line)
      print line
      next
    }
    /"(GET|POST|HEAD) [^ ]+ HTTP/ {
      line = $0
      sub(/^.*"(GET|POST|HEAD) /, "", line)
      sub(/ HTTP.*$/, "", line)
      print line
    }
  ' "$log_file" \
    | awk -v mode="$mode" -v pattern="$pattern" '
        mode == "exact" && ($0 == pattern || index($0, pattern "?") == 1) { count++ }
        mode == "prefix" && index($0, pattern) == 1 { count++ }
        END { print count + 0 }
      '
}

generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
host_name=$(hostname 2>/dev/null || printf 'unknown')
docker_version=$(docker --version 2>/dev/null || printf 'unavailable')
compose_version_text=$(compose_version 2>/dev/null | head -n 1 || printf 'unavailable')
alert_window=$(window_description "$REPORT_LOG_SINCE" "$REPORT_LOG_TAIL_LINES")
page_view_window=$(window_description "$REPORT_PAGE_VIEW_LOG_SINCE" "$REPORT_PAGE_VIEW_LOG_LINES")

collect_infrastructure_report
collect_container_report
collect_deployment_report
collect_security_snapshot
collect_public_endpoint_report
collect_route_report
finalize_performance_summary
finalize_health_score

if [[ ! -s "$finding_rows_file" ]]; then
  emit_file_row "$finding_rows_file" "ok" "Platform" "No warnings or critical findings detected." "0"
fi

top_issue_display="${top_issue_text:-No warnings or critical findings detected.}"
top_issue_class="$(status_class "${top_issue_severity:-ok}")"
average_route_display="$average_route_duration"
slowest_route_duration_display="$slowest_route_duration"
fastest_route_duration_display="$fastest_route_duration"
[[ "$average_route_duration" =~ ^[0-9]+([.][0-9]+)?$ ]] && average_route_display="${average_route_duration}s"
[[ "$slowest_route_duration" =~ ^[0-9]+([.][0-9]+)?$ ]] && slowest_route_duration_display="${slowest_route_duration}s"
[[ "$fastest_route_duration" =~ ^[0-9]+([.][0-9]+)?$ ]] && fastest_route_duration_display="${fastest_route_duration}s"
slowest_route_display="${slowest_route_label} (${slowest_route_duration_display})"
fastest_route_display="${fastest_route_label} (${fastest_route_duration_display})"
top_cpu_display="${top_cpu_service}/${top_cpu_container} (${top_cpu_percent})"
top_memory_display="${top_memory_service}/${top_memory_container} (${top_memory_percent})"
if (( highest_restart_count == 0 )); then
  highest_restart_display="none (0)"
else
  highest_restart_display="${highest_restart_service}/${highest_restart_container} (${highest_restart_count})"
fi

: > "$REPORT_OUTPUT"

emit "<!doctype html>"
emit "<html lang=\"en\">"
emit "<head>"
emit "<meta charset=\"utf-8\">"
emit "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
emit "<title>Portfolio Platform Report</title>"
emit "<style>"
emit "body{font-family:Arial,sans-serif;margin:0;background:#f6f7f9;color:#1f2937}"
emit "main{max-width:1180px;margin:0 auto;padding:28px}"
emit "h1{font-size:28px;margin:0 0 8px}h2{font-size:20px;margin:28px 0 12px}"
emit ".meta{color:#5f6b7a;margin:0 0 20px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px}"
emit ".card{background:#fff;border:1px solid #dde3ea;border-radius:8px;padding:16px}"
emit ".label{font-size:12px;text-transform:uppercase;color:#667085;margin-bottom:6px}.value{font-weight:700;word-break:break-word}"
emit "table{width:100%;border-collapse:collapse;background:#fff;border:1px solid #dde3ea;border-radius:8px;overflow:hidden}"
emit "th,td{text-align:left;border-bottom:1px solid #e5e9ef;padding:10px;vertical-align:top;font-size:14px}th{background:#eef2f7;color:#344054}"
emit ".log-line{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:12px;white-space:pre-wrap;word-break:break-word}"
emit ".pill{display:inline-block;border-radius:999px;padding:3px 8px;font-weight:700;font-size:12px}.ok{background:#dcfce7;color:#166534}.warn{background:#fef3c7;color:#92400e}.bad{background:#fee2e2;color:#991b1b}.muted{background:#e5e7eb;color:#374151}"
emit "</style>"
emit "</head>"
emit "<body><main>"
emit "<h1>Portfolio Platform Report</h1>"
emit "<p class=\"meta\">Generated at $(html_escape "$generated_at") on $(html_escape "$host_name").</p>"

emit "<h2>Executive Summary</h2>"
emit "<section class=\"grid\">"
emit "<div class=\"card\"><div class=\"label\">Overall Status</div><div class=\"value\"><span class=\"pill $(server_status_class)\">$(html_escape "$(server_status)")</span></div></div>"
emit "<div class=\"card\"><div class=\"label\">Health Score</div><div class=\"value\">$(html_escape "$health_score")%</div></div>"
emit "<div class=\"card\"><div class=\"label\">Top Issue</div><div class=\"value\"><span class=\"pill $top_issue_class\">$(html_escape "${top_issue_severity:-ok}")</span> $(html_escape "$top_issue_display")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Slowest Route</div><div class=\"value\">$(html_escape "$slowest_route_display")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Average Route Time</div><div class=\"value\">$(html_escape "$average_route_display")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Rollback Ready</div><div class=\"value\">$(html_escape "$rollback_ready_services_count/$total_services_count")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Top CPU Container</div><div class=\"value\">$(html_escape "$top_cpu_display")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Top Memory Container</div><div class=\"value\">$(html_escape "$top_memory_display")</div></div>"
emit "</section>"

emit "<h2>Platform Health Summary</h2>"
emit "<section class=\"grid\">"
emit "<div class=\"card\"><div class=\"label\">Health Score</div><div class=\"value\">$(html_escape "$health_score")%</div></div>"
emit "<div class=\"card\"><div class=\"label\">Server Status</div><div class=\"value\"><span class=\"pill $(server_status_class)\">$(html_escape "$(server_status)")</span></div></div>"
emit "<div class=\"card\"><div class=\"label\">Running Services</div><div class=\"value\">$(html_escape "$running_services_count/$total_services_count")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Healthy Containers</div><div class=\"value\">$(html_escape "$healthy_containers_count/$total_services_count")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Failed Routes</div><div class=\"value\">$(html_escape "$failed_routes_count")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Slow Routes</div><div class=\"value\">$(html_escape "$slow_routes_count")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Critical Alerts</div><div class=\"value\">$(html_escape "$critical_count")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Warnings</div><div class=\"value\">$(html_escape "$warning_count")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Log Alerts</div><div class=\"value\">$(html_escape "$log_alert_total")</div></div>"
emit "</section>"

emit "<h2>Host Summary</h2>"
emit "<section class=\"grid\">"
emit "<div class=\"card\"><div class=\"label\">Docker</div><div class=\"value\">$(html_escape "$docker_version")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Compose</div><div class=\"value\">$(html_escape "$compose_version_text")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Disk</div><div class=\"value\">$(html_escape "$disk_summary")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Memory</div><div class=\"value\">$(html_escape "$memory_summary")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Route Base URL</div><div class=\"value\">$(html_escape "$REPORT_BASE_URL")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Log Window</div><div class=\"value\">$(html_escape "$alert_window")</div></div>"
emit "</section>"

emit "<h2>Infrastructure Health</h2>"
emit "<table><thead><tr><th>Metric</th><th>Value</th><th>Threshold / Notes</th></tr></thead><tbody>"
emit_row "CPU Cores" "$cpu_cores" "Used with load average thresholding"
emit_row "Load Average" "$load_average" "Warning above CPU cores; critical above 2x CPU cores"
emit_row "Uptime" "$uptime_text" "Host uptime"
emit_row "Disk Usage" "${disk_use_percent}%" "Warning >= ${REPORT_DISK_WARN_PERCENT}%; critical >= ${REPORT_DISK_CRITICAL_PERCENT}%"
emit_row "Memory Usage" "${memory_use_percent}%" "Warning >= ${REPORT_MEMORY_WARN_PERCENT}%; critical >= ${REPORT_MEMORY_CRITICAL_PERCENT}%"
emit_row "Swap Usage" "${swap_use_percent}%" "Warning >= ${REPORT_SWAP_WARN_PERCENT}%; critical >= ${REPORT_SWAP_CRITICAL_PERCENT}%"
emit_row "Network RX/TX" "$network_summary" "Aggregate non-loopback counters from /proc/net/dev when available"
emit "</tbody></table>"

emit "<h2>Public Endpoint Health</h2>"
emit "<table><thead><tr><th>Check</th><th>Target</th><th>Status</th><th>Detail</th></tr></thead><tbody>"
cat "$endpoint_rows_file" >> "$REPORT_OUTPUT"
emit "</tbody></table>"

emit "<h2>Health Findings</h2>"
emit "<table><thead><tr><th>Severity</th><th>Area</th><th>Finding</th><th>Score Impact</th></tr></thead><tbody>"
cat "$finding_rows_file" >> "$REPORT_OUTPUT"
emit "</tbody></table>"

emit "<h2>Container Health</h2>"
emit "<table><thead><tr><th>Service</th><th>Container</th><th>Status</th><th>Health</th><th>Image</th><th>Ports</th><th>Started</th><th>Log Alerts</th></tr></thead><tbody>"
cat "$container_rows_file" >> "$REPORT_OUTPUT"
emit "</tbody></table>"

emit "<h2>Deployment Version And Rollback Readiness</h2>"
emit "<table><thead><tr><th>Service</th><th>Current Image Tag</th><th>Image Digest</th><th>Deployment Age</th><th>N-1 Image Tag</th><th>Rollback Ready</th><th>Release History</th></tr></thead><tbody>"
cat "$deployment_rows_file" >> "$REPORT_OUTPUT"
emit "</tbody></table>"

emit "<h2>Security Snapshot</h2>"
emit "<table><thead><tr><th>Service</th><th>Host Port Bindings</th><th>Privileged</th><th>Docker Socket</th><th>User</th><th>Read-only Root FS</th><th>Sensitive Env Names</th><th>Status / Notes</th></tr></thead><tbody>"
cat "$security_rows_file" >> "$REPORT_OUTPUT"
emit "</tbody></table>"

emit "<h2>Docker Resource Usage</h2>"
emit "<table><thead><tr><th>Service</th><th>Container</th><th>CPU %</th><th>Memory Usage</th><th>Memory %</th><th>Network I/O</th><th>Restart Count</th><th>Image Digest</th></tr></thead><tbody>"
cat "$resource_rows_file" >> "$REPORT_OUTPUT"
emit "</tbody></table>"

emit "<h2>Performance Summary</h2>"
emit "<section class=\"grid\">"
emit "<div class=\"card\"><div class=\"label\">Average Route Time</div><div class=\"value\">$(html_escape "$average_route_display")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Slowest Route</div><div class=\"value\">$(html_escape "$slowest_route_display")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Fastest Route</div><div class=\"value\">$(html_escape "$fastest_route_display")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Top CPU Container</div><div class=\"value\">$(html_escape "$top_cpu_display")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Top Memory Container</div><div class=\"value\">$(html_escape "$top_memory_display")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Highest Restart Count</div><div class=\"value\">$(html_escape "$highest_restart_display")</div></div>"
emit "</section>"
emit "<table><thead><tr><th>Metric</th><th>Value</th><th>Detail</th></tr></thead><tbody>"
emit_row "Average response time" "$average_route_display" "Calculated from ${route_duration_count} public route check(s)."
emit_row "Slowest route" "$slowest_route_display" "$slowest_route_url"
emit_row "Fastest route" "$fastest_route_display" "Status: $fastest_route_status"
emit_row "Top CPU container" "$top_cpu_display" "Point-in-time docker stats sample."
emit_row "Top memory container" "$top_memory_display" "Point-in-time docker stats sample."
emit_row "Highest restart count" "$highest_restart_display" "Docker restart count from inspect."
emit "</tbody></table>"

emit_log_alert_details

emit "<h2>Application Route Health</h2>"
emit "<table><thead><tr><th>Route</th><th>URL</th><th>Status</th><th>Duration Seconds</th><th>Bytes</th></tr></thead><tbody>"
cat "$route_rows_file" >> "$REPORT_OUTPUT"
emit "</tbody></table>"

page_log_file="/tmp/platform-report-portfolio-logs.$$"
if docker ps -aq -f "name=^/portfolio_service$" | grep -q .; then
  docker_logs_window "portfolio_service" "$REPORT_PAGE_VIEW_LOG_LINES" "$REPORT_PAGE_VIEW_LOG_SINCE" > "$page_log_file" 2>&1 || true
else
  : > "$page_log_file"
fi

emit "<h2>Approximate Page Views</h2>"
emit "<p class=\"meta\">Counts are based on portfolio container access logs ($(html_escape "$page_view_window")) and depend on Docker log retention.</p>"
emit "<table><thead><tr><th>Path</th><th>Approximate Requests</th></tr></thead><tbody>"
emit_row "/" "$(count_logged_path exact "/" "$page_log_file")"
emit_row "/blog/" "$(count_logged_path prefix "/blog" "$page_log_file")"
emit_row "/projects/" "$(count_logged_path prefix "/projects" "$page_log_file")"
emit_row "/experience/" "$(count_logged_path prefix "/experience" "$page_log_file")"
emit_row "/contact.html" "$(count_logged_path exact "/contact.html" "$page_log_file")"
emit_row "/api/contact" "$(count_logged_path prefix "/api/contact" "$page_log_file")"
emit "</tbody></table>"

emit "</main></body></html>"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf 'report_path=%s\n' "$REPORT_OUTPUT"
    printf 'report_base_url=%s\n' "$REPORT_BASE_URL"
    printf 'report_log_since=%s\n' "$REPORT_LOG_SINCE"
    printf 'report_date=%s\n' "$(date -u +%Y-%m-%d)"
    printf 'health_score=%s\n' "$health_score"
    printf 'server_status=%s\n' "$(server_status)"
  } >> "$GITHUB_OUTPUT"
fi

cleanup_report_temp_files
trap - ERR

log "SUCCESS" "HTML report generated at $REPORT_OUTPUT."
finish "SUCCESS"
