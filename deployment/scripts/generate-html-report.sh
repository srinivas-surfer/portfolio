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
REPORT_LOG_TAIL_LINES="${REPORT_LOG_TAIL_LINES:-500}"
REPORT_PAGE_VIEW_LOG_LINES="${REPORT_PAGE_VIEW_LOG_LINES:-5000}"
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

  docker logs --tail="$REPORT_LOG_TAIL_LINES" "$container" 2>&1 \
    | grep -Eic 'error|warn|fail|exception|unhealthy' || true
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

  result=$(curl -sS -o /tmp/platform-report-http.out -w '%{http_code}|%{time_total}|%{size_download}' "$url" 2>/tmp/platform-report-http.err || true)
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

  result=$(curl -sS -o /tmp/platform-report-http.out -w '%{http_code}|%{time_total}|%{size_download}' \
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

  sed -n 's/.*"\(GET\|POST\|HEAD\) \([^ ]*\) HTTP.*/\2/p' "$log_file" \
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
  docker logs --tail="$REPORT_PAGE_VIEW_LOG_LINES" portfolio_service > "$page_log_file" 2>&1 || true
else
  : > "$page_log_file"
fi

emit "<h2>Approximate Page Views</h2>"
emit "<p class=\"meta\">Counts are based on the last $(html_escape "$REPORT_PAGE_VIEW_LOG_LINES") portfolio container log lines and depend on Docker log retention.</p>"
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
  printf 'report_path=%s\n' "$REPORT_OUTPUT" >> "$GITHUB_OUTPUT"
fi

log "SUCCESS" "HTML report generated at $REPORT_OUTPUT."
finish "SUCCESS"
