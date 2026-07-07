#!/usr/bin/env bash
set -euo pipefail

LAB_ID="lb-33"
TOPOLOGY="lb-33.clab.yml"
CLIENT="clab-lb-33-client"
LB="clab-lb-33-lb"
VIP="10.0.9.100"
BACKENDS="10.0.10.11 10.0.10.12 10.0.10.13"
REQUESTS="30"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/lb-33/runs/$RUN_ID}"
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

verify() {
  log "starting HTTP responders on the backends"
  local n=1 b
  for b in $BACKENDS; do
    docker exec -d "clab-lb-33-backend${n}" python3 /responder.py "backend${n}"
    n=$((n + 1))
  done

  log "configuring IPVS: VIP $VIP:80, round-robin, NAT (masq) to the backends"
  docker exec "$LB" ipvsadm -C >/dev/null 2>&1 || true
  run_cmd docker exec "$LB" ipvsadm -A -t "$VIP:80" -s rr
  for b in $BACKENDS; do
    run_cmd docker exec "$LB" ipvsadm -a -t "$VIP:80" -r "$b:80" -m
  done
  docker exec "$LB" ipvsadm -L -n | tee "$RUN_DIR/ipvs.txt" | tee -a "$LOG_FILE" >/dev/null

  log "waiting for the VIP to serve"
  local i ok=0
  for i in $(seq 1 30); do
    if docker exec "$CLIENT" curl -s --max-time 2 "http://$VIP/" >/dev/null 2>&1; then
      ok=1; log "VIP answering after ${i}s"; break
    fi
    sleep 1
  done
  [ "$ok" = 1 ]

  log "sending $REQUESTS requests to the VIP and recording which backend answers"
  docker exec "$CLIENT" sh -c "for i in \$(seq 1 $REQUESTS); do curl -s --max-time 3 http://$VIP/; done" \
    >"$RUN_DIR/responses.txt" 2>/dev/null || true

  log "distribution of responses across the backend pool"
  sort "$RUN_DIR/responses.txt" | uniq -c | tee "$RUN_DIR/distribution.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$LB" ipvsadm -L -n --stats | tee "$RUN_DIR/ipvs-stats.txt" | tee -a "$LOG_FILE" >/dev/null

  log "checking the load balancer spread the connections"
  local total distinct min_count
  total="$(grep -c . "$RUN_DIR/responses.txt" || echo 0)"
  distinct="$(sort -u "$RUN_DIR/responses.txt" | grep -c . || echo 0)"
  min_count="$(sort "$RUN_DIR/responses.txt" | uniq -c | awk '{print $1}' | sort -n | head -1)"
  log "total=$total distinct_backends=$distinct min_per_backend=$min_count"
  # Almost all requests succeeded.
  [ "${total:-0}" -ge "$((REQUESTS - 2))" ]
  # All three backends were used.
  [ "${distinct:-0}" -eq 3 ]
  # Round-robin means each backend took roughly a third; require at least a
  # quarter of the even share as a floor (well satisfied by exact rr).
  [ "${min_count:-0}" -ge "$((REQUESTS / 3 / 2))" ]

  write_verification "verified" "L4 load balancing: the client made $REQUESTS connections to the VIP $VIP; IPVS round-robin (NAT mode) spread them across $distinct backends (min $min_count each). The client only ever saw the VIP; the director NATs each connection to a backend and back. One address, a pool of servers, connections distributed."
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
