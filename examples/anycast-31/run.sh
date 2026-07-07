#!/usr/bin/env bash
set -euo pipefail

LAB_ID="anycast-31"
TOPOLOGY="anycast-31.clab.yml"
CLIENT="clab-anycast-31-client"
R1="clab-anycast-31-r1"
SRV_A="clab-anycast-31-server-a"
SRV_B="clab-anycast-31-server-b"
VIP="10.0.0.100"
NH_A="10.0.1.2"   # r1's next-hop toward server-a
NH_B="10.0.2.2"   # r1's next-hop toward server-b
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/anycast-31/runs/$RUN_ID}"
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

# Poll r1's installed route to the VIP until it uses the expected next-hop.
wait_nexthop() {
  local nh="$1" i out
  for i in $(seq 1 40); do
    out="$(docker exec "$R1" ip route get "$VIP" 2>/dev/null || true)"
    if printf '%s' "$out" | grep -q "via $nh"; then
      log "r1 route to $VIP is via $nh (after ${i}s)"
      return 0
    fi
    sleep 1
  done
  log "timed out waiting for r1 route to $VIP via $nh"
  return 1
}

# Fetch the VIP from the client and echo the trimmed body (the server name).
fetch_vip() {
  docker exec "$CLIENT" wget -qO- --timeout=3 "http://$VIP/" 2>/dev/null | tr -d '\r\n'
}

verify() {
  log "starting HTTP identity responders on both servers"
  docker exec -d "$SRV_A" python3 /responder.py server-a
  docker exec -d "$SRV_B" python3 /responder.py server-b

  log "waiting for BGP to converge (r1 should prefer server-a)"
  wait_nexthop "$NH_A"

  docker exec "$R1" vtysh -c "show bgp ipv4 unicast $VIP/32" \
    2>/dev/null | tee "$RUN_DIR/bgp-before.txt" | tee -a "$LOG_FILE" >/dev/null

  log "client fetches the anycast VIP (expect server-a)"
  local before1 before2 before3
  before1="$(fetch_vip)"; before2="$(fetch_vip)"; before3="$(fetch_vip)"
  echo "before: $before1 $before2 $before3" | tee "$RUN_DIR/fetch.txt" | tee -a "$LOG_FILE" >/dev/null
  log "before failover: $before1 $before2 $before3"

  docker exec "$CLIENT" traceroute -n -w1 -q1 -m5 "$VIP" \
    2>/dev/null | tee "$RUN_DIR/traceroute-before.txt" | tee -a "$LOG_FILE" >/dev/null || true

  log "FAILOVER: server-a's uplink goes down"
  run_cmd docker exec "$SRV_A" ip link set eth1 down

  log "waiting for BGP to reconverge onto server-b"
  wait_nexthop "$NH_B"

  docker exec "$R1" vtysh -c "show bgp ipv4 unicast $VIP/32" \
    2>/dev/null | tee "$RUN_DIR/bgp-after.txt" | tee -a "$LOG_FILE" >/dev/null

  log "client fetches the SAME anycast VIP again (expect server-b)"
  local after1 after2 after3
  after1="$(fetch_vip)"; after2="$(fetch_vip)"; after3="$(fetch_vip)"
  echo "after: $after1 $after2 $after3" | tee -a "$RUN_DIR/fetch.txt" | tee -a "$LOG_FILE" >/dev/null
  log "after failover: $after1 $after2 $after3"

  log "restoring server-a's uplink"
  docker exec "$SRV_A" ip link set eth1 up >/dev/null 2>&1 || true

  log "checking anycast behaviour"
  # Before failover the VIP is served by server-a.
  [ "$before1" = "server-a" ]
  [ "$before2" = "server-a" ]
  [ "$before3" = "server-a" ]
  # After server-a fails, the SAME VIP is served by server-b.
  [ "$after1" = "server-b" ]
  [ "$after2" = "server-b" ]
  [ "$after3" = "server-b" ]

  write_verification "verified" "Anycast: server-a and server-b both announce $VIP/32 via BGP. r1 preferred server-a (shorter AS_PATH; server-b prepends), so the client's fetch of http://$VIP/ returned 'server-a'. After server-a's uplink went down, BGP withdrew its route and r1 reconverged onto server-b; the same VIP then returned 'server-b'. One address, two instances, routing chooses and fails over."
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
