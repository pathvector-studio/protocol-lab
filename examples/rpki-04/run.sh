#!/usr/bin/env bash
set -euo pipefail

LAB_ID="rpki-04"
TOPOLOGY="rpki-04.clab.yml"
R2="clab-rpki-04-r2"
STAYRTR="clab-rpki-04-stayrtr"
VALID_PREFIX="203.0.113.0/24"
NOTFOUND_PREFIX="198.51.100.0/24"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/rpki-04/runs/$RUN_ID}"
LOG_FILE="$RUN_DIR/run.log"

mkdir -p "$RUN_DIR"

sudo_cmd() {
  ${SUDO:-sudo} "$@"
}

log() {
  printf '[protocol-lab][%s] %s\n' "$LAB_ID" "$*" | tee -a "$LOG_FILE"
}

run_cmd() {
  log "+ $*"
  "$@" 2>&1 | tee -a "$LOG_FILE"
}

json_escape() {
  printf '%s' "$1" | jq -Rs .
}

write_verification() {
  local status="$1"
  local message="$2"
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

wait_bgp_routes() {
  log "waiting for BGP routes on r2"
  local i
  for i in $(seq 1 45); do
    local output
    output="$(docker exec "$R2" vtysh -c "show bgp ipv4 unicast" 2>/dev/null || true)"
    if grep -q "$VALID_PREFIX" <<<"$output" && grep -q "$NOTFOUND_PREFIX" <<<"$output"; then
      log "BGP routes appeared after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "BGP routes did not appear within timeout"
  return 1
}

wait_rpki_cache() {
  log "waiting for RPKI cache connection and VRP"
  local i
  for i in $(seq 1 45); do
    local cache prefix
    cache="$(docker exec "$R2" vtysh -c "show rpki cache-connection" 2>/dev/null || true)"
    prefix="$(docker exec "$R2" vtysh -c "show rpki prefix $VALID_PREFIX" 2>/dev/null || true)"
    if grep -qi "connected" <<<"$cache" && grep -q "65001" <<<"$prefix"; then
      log "RPKI cache connected after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "RPKI cache did not become ready within timeout"
  return 1
}

verify() {
  wait_bgp_routes
  wait_rpki_cache

  log "collecting FRR and StayRTR output"
  docker logs "$STAYRTR" >"$RUN_DIR/stayrtr.log" 2>&1 || true
  docker exec "$R2" vtysh -c "show bgp summary" | tee "$RUN_DIR/show-bgp-summary-r2.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$R2" vtysh -c "show bgp ipv4 unicast" | tee "$RUN_DIR/show-bgp-ipv4-r2.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$R2" vtysh -c "show rpki cache-connection" | tee "$RUN_DIR/show-rpki-cache-connection-r2.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$R2" vtysh -c "show rpki prefix-table" | tee "$RUN_DIR/show-rpki-prefix-table-r2.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$R2" vtysh -c "show rpki prefix $VALID_PREFIX" | tee "$RUN_DIR/show-rpki-prefix-203.0.113.0_24-r2.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$R2" vtysh -c "show bgp ipv4 unicast rpki valid" | tee "$RUN_DIR/show-bgp-rpki-valid-r2.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$R2" vtysh -c "show bgp ipv4 unicast rpki invalid" | tee "$RUN_DIR/show-bgp-rpki-invalid-r2.txt" | tee -a "$LOG_FILE" >/dev/null

  log "checking expected validation states"
  grep -qi "connected" "$RUN_DIR/show-rpki-cache-connection-r2.txt"
  grep -q "65001" "$RUN_DIR/show-rpki-prefix-table-r2.txt"
  grep -q "N.*$NOTFOUND_PREFIX.*10.0.24.2.*65004" "$RUN_DIR/show-bgp-ipv4-r2.txt"
  grep -q "V.*$VALID_PREFIX.*10.0.12.1.*65001" "$RUN_DIR/show-bgp-rpki-valid-r2.txt"
  grep -q "I.*$VALID_PREFIX.*10.0.23.2.*65003" "$RUN_DIR/show-bgp-rpki-invalid-r2.txt"

  write_verification "verified" "RPKI origin validation states are visible on r2: valid AS65001, invalid AS65003, and not found AS65004."
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
  command -v tshark
  sudo_cmd /usr/sbin/ip netns list >/dev/null
}

action="${1:-run}"

case "$action" in
  deploy)
    deploy
    ;;
  verify)
    verify
    ;;
  destroy)
    destroy
    ;;
  doctor)
    doctor
    ;;
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
