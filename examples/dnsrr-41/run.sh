#!/usr/bin/env bash
set -euo pipefail

LAB_ID="dnsrr-41"
TOPOLOGY="dnsrr-41.clab.yml"
BIND_IMAGE="protocol-lab/bind9:9.20"
CLIENT="clab-dnsrr-41-client"
DNS_IP="10.0.0.2"
NAME="web.lab"
QUERIES="6"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/dnsrr-41/runs/$RUN_ID}"
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

build_image() {
  log "building $BIND_IMAGE"
  run_cmd docker build -t "$BIND_IMAGE" "$LAB_DIR"
}

deploy() {
  log "deploying topology"
  sudo_cmd containerlab destroy -t "$TOPOLOGY" --cleanup >/dev/null 2>&1 || true
  run_cmd sudo_cmd containerlab deploy -t "$TOPOLOGY"
}

first_a() { docker exec "$CLIENT" sh -c "dig +short $NAME @$DNS_IP | grep -E '^[0-9]' | head -1" 2>/dev/null; }

verify() {
  log "waiting for the authoritative server to answer $NAME"
  local i ready=0
  for i in $(seq 1 30); do
    if [ -n "$(first_a)" ]; then ready=1; log "server answering after ${i}s"; break; fi
    sleep 1
  done
  [ "$ready" = 1 ]

  log "full answer for $NAME (three A records)"
  docker exec "$CLIENT" dig +noall +answer "$NAME" @"$DNS_IP" \
    | tee "$RUN_DIR/answer.txt" | tee -a "$LOG_FILE" >/dev/null
  local a_count
  a_count="$(grep -cE '\sA\s' "$RUN_DIR/answer.txt" || echo 0)"

  log "querying $QUERIES times; recording the FIRST A record each time"
  : >"$RUN_DIR/first-records.txt"
  for i in $(seq 1 "$QUERIES"); do
    first_a >>"$RUN_DIR/first-records.txt"
  done
  cat "$RUN_DIR/first-records.txt" | tee -a "$LOG_FILE" >/dev/null
  local distinct
  distinct="$(sort -u "$RUN_DIR/first-records.txt" | grep -cE '^[0-9]' || echo 0)"
  log "distinct first-records across $QUERIES queries: $distinct"

  log "checking round-robin rotation"
  # The name really has three A records.
  [ "${a_count:-0}" -eq 3 ]
  # The server rotated them: the first-returned record took all three values.
  [ "${distinct:-0}" -eq 3 ]

  write_verification "verified" "DNS round-robin: $NAME has three A records (203.0.113.11/.12/.13). With 'rrset-order cyclic', the authoritative server rotated their order on each response — across $QUERIES queries the first-returned address cycled through all three, spreading clients across the backends at the resolver layer."
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
  deploy) build_image; deploy ;;
  verify) verify ;;
  destroy) destroy ;;
  doctor) doctor ;;
  run)
    trap destroy EXIT
    build_image
    deploy
    verify
    log "run complete: $RUN_DIR"
    ;;
  *)
    echo "Usage: $0 {run|deploy|verify|destroy|doctor}" >&2
    exit 1
    ;;
esac
