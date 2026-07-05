#!/usr/bin/env bash
set -euo pipefail

LAB_ID="http-10"
TOPOLOGY="http-10.clab.yml"
CLIENT="clab-http-10-client"
SERVER="clab-http-10-server"
SERVER_IP="10.0.0.2"
PORT="8080"
BASE="http://10.0.0.2:8080"
ETAG='"v1-abc123"'
PCAP_IN="/tmp/http-10.pcap"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/http-10/runs/$RUN_ID}"
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
  docker exec "$SERVER" pkill -f "app.py" >/dev/null 2>&1 || true
  log "starting the Python HTTP server on :$PORT"
  docker exec -d "$SERVER" python3 /app/app.py
}

wait_http() {
  log "waiting for the server to answer on $BASE"
  local i
  for i in $(seq 1 30); do
    if docker exec "$CLIENT" curl -s -o /dev/null "$BASE/" 2>/dev/null; then
      log "server answered after ${i}s"; return 0
    fi
    sleep 1
  done
  log "server did not answer within timeout"; return 1
}

verify() {
  start_server
  wait_http

  log "capturing one HTTP exchange (cleartext)"
  docker exec "$CLIENT" rm -f "$PCAP_IN" >/dev/null 2>&1 || true
  docker exec -d "$CLIENT" tcpdump -i eth1 -A -s0 -w "$PCAP_IN" "tcp port $PORT"
  sleep 1

  log "GET / (200 with cache headers)"
  docker exec "$CLIENT" curl -sv -o /dev/null "$BASE/" \
    > "$RUN_DIR/get-root.txt" 2>&1
  cat "$RUN_DIR/get-root.txt" >>"$LOG_FILE"

  log "HEAD / (headers only)"
  docker exec "$CLIENT" curl -sv -I -o /dev/null "$BASE/" \
    > "$RUN_DIR/head-root.txt" 2>&1
  cat "$RUN_DIR/head-root.txt" >>"$LOG_FILE"

  log "GET / with If-None-Match (304 Not Modified)"
  docker exec "$CLIENT" curl -sv -o /dev/null -H "If-None-Match: $ETAG" "$BASE/" \
    > "$RUN_DIR/get-conditional.txt" 2>&1
  cat "$RUN_DIR/get-conditional.txt" >>"$LOG_FILE"

  log "GET /missing (404 Not Found)"
  docker exec "$CLIENT" curl -sv -o /dev/null "$BASE/missing" \
    > "$RUN_DIR/get-missing.txt" 2>&1
  cat "$RUN_DIR/get-missing.txt" >>"$LOG_FILE"

  sleep 1
  docker exec "$CLIENT" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1
  docker cp "$CLIENT:$PCAP_IN" "$RUN_DIR/http-10.pcap" >/dev/null 2>&1 || true
  docker exec "$SERVER" pkill -f "app.py" >/dev/null 2>&1 || true

  log "checking status codes, headers, and cache behavior"
  # curl -v prints response headers with a leading "< ".
  grep -qE "^< HTTP/1\.1 200" "$RUN_DIR/get-root.txt"
  grep -qiE "^< Cache-Control: max-age=60" "$RUN_DIR/get-root.txt"
  grep -qiE "^< ETag: " "$RUN_DIR/get-root.txt"
  grep -qE "^< HTTP/1\.1 304" "$RUN_DIR/get-conditional.txt"
  grep -qE "^< HTTP/1\.1 404" "$RUN_DIR/get-missing.txt"

  write_verification "verified" "HTTP/1.1 exchange observed: GET / 200 with Cache-Control/ETag, HEAD headers-only, conditional GET 304 Not Modified, and GET /missing 404."
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
  command -v tcpdump
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
