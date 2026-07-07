#!/usr/bin/env bash
set -euo pipefail

LAB_ID="ndp-23"
TOPOLOGY="ndp-23.clab.yml"
A="clab-ndp-23-node-a"
B="clab-ndp-23-node-b"
A_V6="2001:db8:23::1"
B_V6="2001:db8:23::2"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/ndp-23/runs/$RUN_ID}"
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

wait_v6() {
  log "waiting for IPv6 connectivity ($A_V6 -> $B_V6)"
  local i
  for i in $(seq 1 30); do
    if docker exec "$A" ping6 -c1 -W1 "$B_V6" >/dev/null 2>&1; then
      log "IPv6 reachable after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "IPv6 not reachable within timeout"
  return 1
}

verify() {
  wait_v6

  log "clearing node-a's neighbor cache so discovery happens fresh"
  docker exec "$A" ip -6 neigh flush all >/dev/null 2>&1 || true
  docker exec "$A" ip -6 neigh show dev eth1 | tee "$RUN_DIR/neigh-before.txt" | tee -a "$LOG_FILE" >/dev/null

  log "capturing ICMPv6 while node-a discovers node-b"
  docker exec "$A" rm -f /tmp/ndp.pcap >/dev/null 2>&1 || true
  docker exec -d "$A" tcpdump -i eth1 -n -s0 -w /tmp/ndp.pcap "icmp6"
  sleep 1
  docker exec "$A" ping6 -c2 -W2 "$B_V6" 2>&1 | tee "$RUN_DIR/ping6.txt" | tee -a "$LOG_FILE" >/dev/null
  sleep 1
  docker exec "$A" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1

  docker cp "$A:/tmp/ndp.pcap" "$RUN_DIR/ndp.pcap" >/dev/null 2>&1 || true
  docker exec "$A" tcpdump -n -e -vv -r /tmp/ndp.pcap 2>/dev/null \
    | tee "$RUN_DIR/ndp-decoded.txt" >/dev/null || true
  # The neighbor cache now holds node-b's link-layer address.
  docker exec "$A" ip -6 neigh show dev eth1 | tee "$RUN_DIR/neigh-after.txt" | tee -a "$LOG_FILE" >/dev/null

  log "checking neighbor discovery"
  # The ping6 worked.
  grep -qE "2 (packets )?received|0% packet loss" "$RUN_DIR/ping6.txt"
  # A Neighbor Solicitation and a Neighbor Advertisement were exchanged.
  grep -qi "neighbor solicitation" "$RUN_DIR/ndp-decoded.txt"
  grep -qi "neighbor advertisement" "$RUN_DIR/ndp-decoded.txt"
  # The solicitation went to a solicited-node multicast address (ff02::1:ff..).
  grep -qiE "ff02::1:ff" "$RUN_DIR/ndp-decoded.txt"
  # After discovery, node-b is in the neighbor table with a MAC (lladdr).
  grep -qiE "$B_V6 .*lladdr" "$RUN_DIR/neigh-after.txt"

  write_verification "verified" "IPv6 Neighbor Discovery: with the cache cleared, node-a resolved $B_V6 by sending a Neighbor Solicitation to the solicited-node multicast address and receiving a Neighbor Advertisement with node-b's MAC; the neighbor table then held node-b's lladdr. This is what ARP does on IPv4, via ICMPv6 and multicast."
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
