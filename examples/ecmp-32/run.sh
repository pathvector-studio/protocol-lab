#!/usr/bin/env bash
set -euo pipefail

LAB_ID="ecmp-32"
TOPOLOGY="ecmp-32.clab.yml"
CLIENT="clab-ecmp-32-client"
R1="clab-ecmp-32-r1"
SERVER="clab-ecmp-32-server"
SERVER_IP="10.0.8.2"
SERVER_NET="10.0.8.0/24"
STREAMS="16"
DURATION="6"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/ecmp-32/runs/$RUN_ID}"
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

# r1's TX bytes on a given interface.
tx_bytes() { docker exec "$R1" cat "/sys/class/net/$1/statistics/tx_bytes" 2>/dev/null || echo 0; }

# Wait until r1's route to the server subnet has two next-hops (ECMP installed).
wait_ecmp() {
  local i n
  for i in $(seq 1 40); do
    n="$(docker exec "$R1" ip route show "$SERVER_NET" 2>/dev/null | grep -c 'nexthop' || true)"
    if [ "${n:-0}" -ge 2 ]; then
      log "r1 has a ${n}-way ECMP route to $SERVER_NET (after ${i}s)"
      return 0
    fi
    sleep 1
  done
  log "timed out waiting for ECMP route"
  return 1
}

verify() {
  docker exec "$SERVER" pkill -f "iperf3 -s" >/dev/null 2>&1 || true
  log "starting iperf3 server"
  docker exec -d "$SERVER" sh -c "iperf3 -s >/tmp/iperf.log 2>&1"
  sleep 1

  log "waiting for BGP to install the equal-cost multipath route"
  wait_ecmp
  docker exec "$R1" ip route show "$SERVER_NET" | tee "$RUN_DIR/ecmp-route.txt" | tee -a "$LOG_FILE" >/dev/null

  local policy
  policy="$(docker exec "$R1" sysctl -n net.ipv4.fib_multipath_hash_policy 2>/dev/null || echo 0)"
  log "r1 multipath hash policy = $policy (1 = include L4 ports)"

  log "running $STREAMS parallel flows client -> server, measuring both links on r1"
  local b2 b3 a2 a3 d2 d3 total
  b2="$(tx_bytes eth2)"; b3="$(tx_bytes eth3)"
  docker exec "$CLIENT" iperf3 -c "$SERVER_IP" -P "$STREAMS" -t "$DURATION" 2>&1 \
    | tee "$RUN_DIR/iperf.txt" | tail -3 | tee -a "$LOG_FILE" >/dev/null || true
  a2="$(tx_bytes eth2)"; a3="$(tx_bytes eth3)"
  d2=$((a2 - b2)); d3=$((a3 - b3)); total=$((d2 + d3))

  {
    echo "policy: $policy"
    echo "eth2 (link A) tx delta: $d2 bytes"
    echo "eth3 (link B) tx delta: $d3 bytes"
    echo "total: $total bytes"
  } | tee "$RUN_DIR/link-bytes.txt" | tee -a "$LOG_FILE" >/dev/null
  log "eth2=${d2} eth3=${d3} (total ${total})"

  docker exec "$SERVER" pkill -f "iperf3 -s" >/dev/null 2>&1 || true

  log "checking both equal-cost links carried the flows"
  # The route really is multipath.
  [ "$(docker exec "$R1" ip route show "$SERVER_NET" | grep -c 'nexthop')" -ge 2 ]
  # Some traffic actually flowed.
  [ "$total" -gt 10000000 ]
  # Both links carried a meaningful share (>=10% of the total each) — proving the
  # flows were hashed across the pair, not pinned to one link.
  [ "$((d2 * 100 / total))" -ge 10 ]
  [ "$((d3 * 100 / total))" -ge 10 ]

  write_verification "verified" "ECMP: r1 installed a two-next-hop BGP route to $SERVER_NET (via both parallel links). With L4 multipath hashing (fib_multipath_hash_policy=$policy), $STREAMS parallel TCP flows were spread across both links: eth2 carried $d2 bytes and eth3 carried $d3 bytes (of $total total). Equal-cost multipath splits flows, not packets."
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
