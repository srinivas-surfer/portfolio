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

mkdir -p "$(dirname "$REPORT_OUTPUT")"

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
    unhealthy | exited | dead | failed | 000 | 4?? | 5??) printf 'bad' ;;
    missing | unknown | unavailable) printf 'warn' ;;
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

http_check() {
  local label="$1"
  local path="$2"
  local url="${REPORT_BASE_URL}${path}"
  local result status duration bytes css

  if ! command -v curl >/dev/null 2>&1; then
    emit_row "$label" "$url" "curl missing" "unavailable" "unavailable"
    return
  fi

  result=$(curl -sS -A "Portfolio-Report-HealthCheck" -o /tmp/platform-report-http.out -w '%{http_code}|%{time_total}|%{size_download}' "$url" 2>/tmp/platform-report-http.err || true)
  status="${result%%|*}"
  result="${result#*|}"
  duration="${result%%|*}"
  bytes="${result#*|}"
  [[ -n "$status" ]] || status="failed"
  css=$(status_class "$status")

  emit "<tr><td>$(html_escape "$label")</td><td>$(html_escape "$url")</td><td><span class=\"pill $css\">$(html_escape "$status")</span></td><td>$(html_escape "$duration")</td><td>$(html_escape "$bytes")</td></tr>"
}

contact_contract_check() {
  local label="Contact API Contract"
  local url="${REPORT_BASE_URL}/api/contact"
  local result status duration bytes display_status css

  if ! command -v curl >/dev/null 2>&1; then
    emit_row "$label" "$url" "curl missing" "unavailable" "unavailable"
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
  fi

  css=$(status_class "$display_status")
  emit "<tr><td>$(html_escape "$label")</td><td>$(html_escape "$url")</td><td><span class=\"pill $css\">$(html_escape "$display_status")</span></td><td>$(html_escape "$duration")</td><td>$(html_escape "$bytes")</td></tr>"
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
disk_summary=$(df -h . | awk 'NR == 2 { print "size=" $2 ", used=" $3 ", available=" $4 ", use=" $5 }')
memory_summary="unavailable"
alert_window=$(window_description "$REPORT_LOG_SINCE" "$REPORT_LOG_TAIL_LINES")
page_view_window=$(window_description "$REPORT_PAGE_VIEW_LOG_SINCE" "$REPORT_PAGE_VIEW_LOG_LINES")

if [[ -r /proc/meminfo ]]; then
  memory_summary=$(awk '
    /MemTotal/ { total = int($2 / 1024) }
    /MemAvailable/ { available = int($2 / 1024) }
    /SwapTotal/ { swap_total = int($2 / 1024) }
    /SwapFree/ { swap_free = int($2 / 1024) }
    END {
      printf "memory_total=%sMB, memory_available=%sMB, swap_total=%sMB, swap_free=%sMB", total, available, swap_total, swap_free
    }
  ' /proc/meminfo)
elif command -v vm_stat >/dev/null 2>&1; then
  memory_summary=$(vm_stat | tr '\n' ' ' | sed 's/[[:space:]]*$//')
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

emit "<section class=\"grid\">"
emit "<div class=\"card\"><div class=\"label\">Docker</div><div class=\"value\">$(html_escape "$docker_version")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Compose</div><div class=\"value\">$(html_escape "$compose_version_text")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Disk</div><div class=\"value\">$(html_escape "$disk_summary")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Memory</div><div class=\"value\">$(html_escape "$memory_summary")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Route Base URL</div><div class=\"value\">$(html_escape "$REPORT_BASE_URL")</div></div>"
emit "<div class=\"card\"><div class=\"label\">Log Window</div><div class=\"value\">$(html_escape "$alert_window")</div></div>"
emit "</section>"

emit "<h2>Container Health</h2>"
emit "<table><thead><tr><th>Service</th><th>Container</th><th>Status</th><th>Health</th><th>Image</th><th>Ports</th><th>Started</th><th>Log Alerts</th></tr></thead><tbody>"

IFS=',' read -r -a report_services <<< "$REPORT_SERVICES"
for service in "${report_services[@]}"; do
  service="${service//[[:space:]]/}"
  [[ -z "$service" ]] && continue

  set_service_context "$service"
  if docker ps -aq -f "name=^/${CONTAINER_NAME}$" | grep -q .; then
    state=$(container_value "$CONTAINER_NAME" '{{.State.Status}}')
    health=$(container_health "$CONTAINER_NAME")
    image=$(container_value "$CONTAINER_NAME" '{{.Config.Image}}')
    started=$(container_value "$CONTAINER_NAME" '{{.State.StartedAt}}')
    ports=$(container_ports "$CONTAINER_NAME")
    alerts=$(service_error_count "$CONTAINER_NAME")
  else
    state="missing"
    health="missing"
    image="missing"
    started="missing"
    ports="none"
    alerts="0"
  fi

  state_css=$(status_class "$state")
  health_css=$(status_class "$health")
  emit "<tr><td>$(html_escape "$SERVICE_NAME")</td><td>$(html_escape "$CONTAINER_NAME")</td><td><span class=\"pill $state_css\">$(html_escape "$state")</span></td><td><span class=\"pill $health_css\">$(html_escape "$health")</span></td><td>$(html_escape "$image")</td><td>$(html_escape "$ports")</td><td>$(html_escape "$started")</td><td>$(html_escape "$alerts")</td></tr>"
done
emit "</tbody></table>"

emit_log_alert_details

emit "<h2>Application Route Health</h2>"
emit "<table><thead><tr><th>Route</th><th>URL</th><th>Status</th><th>Duration Seconds</th><th>Bytes</th></tr></thead><tbody>"
http_check "Home" "/"
http_check "Blog" "/blog/"
http_check "Projects" "/projects/"
http_check "Experience" "/experience/"
http_check "Contact Page" "/contact.html"
contact_contract_check
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

rm -f "$page_log_file" /tmp/platform-report-http.out /tmp/platform-report-http.err

emit "</main></body></html>"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf 'report_path=%s\n' "$REPORT_OUTPUT"
    printf 'report_base_url=%s\n' "$REPORT_BASE_URL"
    printf 'report_log_since=%s\n' "$REPORT_LOG_SINCE"
    printf 'report_date=%s\n' "$(date -u +%Y-%m-%d)"
  } >> "$GITHUB_OUTPUT"
fi

log "SUCCESS" "HTML report generated at $REPORT_OUTPUT."
finish "SUCCESS"
