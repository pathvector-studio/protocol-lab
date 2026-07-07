#!/usr/bin/env bash
set -euo pipefail

LAB_ID="http-27"
TOPOLOGY="http-27.clab.yml"
CLIENT="clab-http-27-client"
SERVER="clab-http-27-server"
BASE="http://10.0.0.2:8080"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/http-27/runs/$RUN_ID}"
LOG_FILE="$RUN_DIR/run.log"

mkdir -p "$RUN_DIR"

sudo_cmd() { ${SUDO:-sudo} "$@"; }
log() { printf '[protocol-lab][%s] %s\n' "$LAB_ID" "$*" | tee -a "$LOG_FILE"; }
run_cmd() { log "+ $*"; "$@" 2>&1 | tee -a "$LOG_FILE"; }
json_escape() { printf '%s' "$1" | jq -Rs .; }

write_verification() {
  local status="$1" message="$2"
  cat >"$RUN_DIR/verification.json" <<JSON
{
  "lab": "$LAB_ID",
  "run_id": "$RUN_ID",
  "status": "$status",
  "message": $(json_escape "$message"),
  "run_dir": $(json_escape "$RUN_DIR")
}
JSON
}

deploy() {
  log "deploying topology"
  sudo_cmd containerlab destroy -t "$TOPOLOGY" --cleanup >/dev/null 2>&1 || true
  run_cmd sudo_cmd containerlab deploy -t "$TOPOLOGY"
}

start_server() {
  docker exec "$SERVER" pkill -f app.py >/dev/null 2>&1 || true
  log "starting the HTTP app on the server"
  docker exec -d "$SERVER" sh -c "python3 /app/app.py >/tmp/app.log 2>&1"
  sleep 1
}

wait_ready() {
  log "waiting for the server"
  local i
  for i in $(seq 1 30); do
    if docker exec "$CLIENT" curl -s -o /dev/null "$BASE/new" 2>/dev/null; then
      log "server up after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "server not reachable within timeout"
  return 1
}

verify() {
  start_server
  wait_ready

  log "1) GET /old without following: a 302 with a Location header"
  docker exec "$CLIENT" curl -sD - -o /dev/null "$BASE/old" \
    | tee "$RUN_DIR/redirect-headers.txt" | tee -a "$LOG_FILE" >/dev/null

  log "2) GET /old following redirects (curl -L): ends up at /new"
  docker exec "$CLIENT" curl -sL -w "\n[final-url] %{url_effective}\n" "$BASE/old" \
    | tee "$RUN_DIR/redirect-followed.txt" | tee -a "$LOG_FILE" >/dev/null

  log "3) GET /new and store the cookie (curl -c)"
  docker exec "$CLIENT" sh -c "curl -sD - -o /dev/null -c /tmp/jar.txt $BASE/new" \
    | tee "$RUN_DIR/set-cookie.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$CLIENT" cat /tmp/jar.txt | tee "$RUN_DIR/cookie-jar.txt" >/dev/null 2>&1 || true

  log "4) GET /whoami sending the stored cookie (curl -b): server echoes it"
  docker exec "$CLIENT" sh -c "curl -s -b /tmp/jar.txt $BASE/whoami" \
    | tee "$RUN_DIR/whoami.txt" | tee -a "$LOG_FILE" >/dev/null

  log "checking redirects and cookies"
  # A 302 with Location: /new.
  grep -qE "HTTP/1\.[01] 302" "$RUN_DIR/redirect-headers.txt"
  grep -qiE "^location: */new" "$RUN_DIR/redirect-headers.txt"
  # Following it lands on /new.
  grep -qE "\[final-url\].*/new" "$RUN_DIR/redirect-followed.txt"
  # /new set a cookie ...
  grep -qiE "^set-cookie: *session=abc123" "$RUN_DIR/set-cookie.txt"
  # ... which the client stored and sent back to /whoami.
  grep -q "session=abc123" "$RUN_DIR/whoami.txt"

  write_verification "verified" "HTTP: GET /old returned 302 with Location: /new (curl -L followed it to /new); GET /new sent Set-Cookie: session=abc123, which curl stored and resent so GET /whoami echoed 'Cookie: session=abc123'."
  log "verification OK"
}

destroy() {
  log "destroying topology"
  sudo_cmd containerlab destroy -t "$TOPOLOGY" --cleanup 2>&1 | tee -a "$LOG_FILE" || true
}

doctor() {
  log "doctor"
  command -v docker
  command -v containerlab
  sudo_cmd /usr/sbin/ip netns list >/dev/null
}

action="${1:-run}"
case "$action" in
  deploy) deploy ;;
  verify) verify ;;
  destroy) destroy ;;
  doctor) doctor ;;
  run)
    trap destroy EXIT
    deploy
    verify
    log "run complete: $RUN_DIR"
    ;;
  *)
    echo "Usage: $0 {run|deploy|verify|destroy|doctor}" >&2
    exit 1
    ;;
esac
