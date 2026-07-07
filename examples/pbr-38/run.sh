#!/usr/bin/env bash
set -euo pipefail

LAB_ID="pbr-38"
TOPOLOGY="pbr-38.clab.yml"
SRCA="clab-pbr-38-srcA"
SRCB="clab-pbr-38-srcB"
R="clab-pbr-38-r"
UP1="clab-pbr-38-up1"
UP2="clab-pbr-38-up2"
VIP="10.0.100.1"
SRCB_IP="10.0.5.2"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/pbr-38/runs/$RUN_ID}"
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

# Fetch the service VIP from a source and echo which uplink answered.
fetch() { docker exec "$1" curl -s --max-time 4 "http://$VIP/" 2>/dev/null | tr -d '\r\n'; }

verify() {
  log "starting HTTP identity responders on both uplinks (both own $VIP)"
  docker exec -d "$UP1" python3 /responder.py up1
  docker exec -d "$UP2" python3 /responder.py up2
  sleep 1

  log "BASELINE — destination-based routing (r's main table sends $VIP via up1)"
  local a0 b0
  a0="$(fetch "$SRCA")"; b0="$(fetch "$SRCB")"
  echo "baseline: srcA=$a0 srcB=$b0" | tee "$RUN_DIR/result.txt" | tee -a "$LOG_FILE" >/dev/null
  log "baseline: srcA=$a0 srcB=$b0 (both take the same path — routing by destination)"

  log "adding a policy route: traffic FROM srcB uses table 200 (default via up2)"
  run_cmd docker exec "$R" sh -c '
    ip route replace default via 10.0.3.2 table 200
    ip rule add from '"$SRCB_IP"' lookup 200
  '
  docker exec "$R" ip rule | tee "$RUN_DIR/ip-rule.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$R" ip route show table 200 | tee "$RUN_DIR/table200.txt" | tee -a "$LOG_FILE" >/dev/null

  log "AFTER policy — same destination, path now depends on the source"
  local a1 b1
  a1="$(fetch "$SRCA")"; b1="$(fetch "$SRCB")"
  echo "after: srcA=$a1 srcB=$b1" | tee -a "$RUN_DIR/result.txt" | tee -a "$LOG_FILE" >/dev/null
  log "after: srcA=$a1 srcB=$b1 (srcB now steered to up2 by source policy)"

  log "checking policy routing changed the path by source"
  # Baseline: destination-based, so both sources take the same uplink.
  [ "$a0" = "up1" ]
  [ "$b0" = "up1" ]
  # After the policy: srcA is unchanged, srcB is steered to the other uplink,
  # even though the destination ($VIP) is identical.
  [ "$a1" = "up1" ]
  [ "$b1" = "up2" ]

  write_verification "verified" "Policy routing: both uplinks host the same service address $VIP. With destination-based routing, srcA and srcB both reached up1. After adding 'ip rule from $SRCB_IP lookup 200' (table 200 default via up2), srcA still reached up1 but srcB reached up2 — the same destination routed over different uplinks based on the source."
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
