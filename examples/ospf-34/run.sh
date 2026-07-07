#!/usr/bin/env bash
set -euo pipefail

LAB_ID="ospf-34"
TOPOLOGY="ospf-34.clab.yml"
R1="clab-ospf-34-r1"
TARGET_IP="10.0.30.1"
TARGET_NET="10.0.30.0/24"
NH_DIRECT="10.0.13.2"   # r1 -> r3 direct
NH_VIA_R2="10.0.12.2"   # r1 -> r2 (two-hop path)
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/ospf-34/runs/$RUN_ID}"
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

# Wait until r1 has two Full OSPF adjacencies.
wait_full() {
  local i n
  for i in $(seq 1 60); do
    n="$(docker exec "$R1" vtysh -c 'show ip ospf neighbor' 2>/dev/null | grep -c 'Full' || true)"
    if [ "${n:-0}" -ge 2 ]; then
      log "r1 has $n Full OSPF adjacencies (after ${i}s)"
      return 0
    fi
    sleep 1
  done
  log "timed out waiting for Full adjacencies"
  return 1
}

# Wait until r1's kernel route to the target uses the expected next-hop.
wait_nexthop() {
  local nh="$1" i out
  for i in $(seq 1 40); do
    out="$(docker exec "$R1" ip route get "$TARGET_IP" 2>/dev/null || true)"
    if printf '%s' "$out" | grep -q "via $nh"; then
      log "r1 route to $TARGET_IP is via $nh (after ${i}s)"
      return 0
    fi
    sleep 1
  done
  log "timed out waiting for r1 route via $nh"
  return 1
}

ping_ok() { docker exec "$R1" ping -c2 -W1 "$TARGET_IP" >/dev/null 2>&1; }

verify() {
  log "waiting for OSPF adjacencies to reach Full"
  wait_full
  docker exec "$R1" vtysh -c "show ip ospf neighbor" \
    2>/dev/null | tee "$RUN_DIR/neighbors.txt" | tee -a "$LOG_FILE" >/dev/null

  log "waiting for the SPF route to the target (direct r1-r3 link, lower cost)"
  wait_nexthop "$NH_DIRECT"
  # Kernel route (single, unambiguous line) drives the assertion; the vtysh OSPF
  # table (with the [110/cost] metric) is kept for the record.
  docker exec "$R1" ip route get "$TARGET_IP" \
    2>/dev/null | tee "$RUN_DIR/route-before.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$R1" vtysh -c "show ip route ospf" \
    2>/dev/null | tee "$RUN_DIR/ospf-table-before.txt" | tee -a "$LOG_FILE" >/dev/null

  log "reachability before failover"
  ping_ok && log "target reachable via direct path" || { log "target unreachable"; return 1; }

  log "FAILOVER: the direct r1-r3 link goes down"
  run_cmd docker exec "$R1" ip link set eth2 down

  log "waiting for OSPF to reconverge onto the two-hop path via r2"
  wait_nexthop "$NH_VIA_R2"
  docker exec "$R1" ip route get "$TARGET_IP" \
    2>/dev/null | tee "$RUN_DIR/route-after.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$R1" vtysh -c "show ip route ospf" \
    2>/dev/null | tee "$RUN_DIR/ospf-table-after.txt" | tee -a "$LOG_FILE" >/dev/null

  log "reachability after reconvergence"
  local after_ok=0
  ping_ok && { after_ok=1; log "target still reachable via r2"; } || log "target unreachable after failover"

  log "restoring the direct r1-r3 link"
  docker exec "$R1" ip link set eth2 up >/dev/null 2>&1 || true

  # Capture the OSPF cost of the target route before/after for the record.
  local metric_before metric_after
  metric_before="$(grep '10.0.30.0/24' "$RUN_DIR/ospf-table-before.txt" | grep -oE '\[110/[0-9]+\]' | head -1 || true)"
  metric_after="$(grep '10.0.30.0/24' "$RUN_DIR/ospf-table-after.txt" | grep -oE '\[110/[0-9]+\]' | head -1 || true)"
  log "route metric before=${metric_before:-?} after=${metric_after:-?}"

  log "checking OSPF adjacency, SPF path, and reconvergence"
  # Two Full adjacencies formed.
  [ "$(docker exec "$R1" vtysh -c 'show ip ospf neighbor' 2>/dev/null | grep -c 'Full')" -ge 2 ]
  # Before failover the target was routed over the direct link.
  grep -q "via $NH_DIRECT" "$RUN_DIR/route-before.txt"
  # After failover it reconverged onto the path via r2.
  grep -q "via $NH_VIA_R2" "$RUN_DIR/route-after.txt"
  # And it stayed reachable across the failover.
  [ "$after_ok" = 1 ]

  write_verification "verified" "OSPF: r1 formed Full adjacencies with r2 and r3 in area 0. SPF chose the direct r1-r3 link (cost 20) to reach $TARGET_NET over the two-hop r1-r2-r3 path (cost 30). When the direct link failed, OSPF reconverged onto the path via r2 (${metric_after:-metric 30}) and the target stayed reachable — link-state flooding plus Dijkstra, not a path vector."
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
