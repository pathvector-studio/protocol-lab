#!/usr/bin/env bash
set -euo pipefail

LAB_ID="arp-24"
TOPOLOGY="arp-24.clab.yml"
A="clab-arp-24-node-a"
B="clab-arp-24-node-b"
A_IP="10.0.0.1"
B_IP="10.0.0.2"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/arp-24/runs/$RUN_ID}"
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

wait_link() {
  log "waiting for the link ($A_IP -> $B_IP)"
  local i
  for i in $(seq 1 30); do
    if docker exec "$A" ping -c1 -W1 "$B_IP" >/dev/null 2>&1; then
      log "link up after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "link did not come up within timeout"
  return 1
}

verify() {
  wait_link

  log "clearing node-a's ARP cache so resolution happens fresh"
  docker exec "$A" ip neigh flush all >/dev/null 2>&1 || true
  docker exec "$A" ip neigh show dev eth1 | tee "$RUN_DIR/arp-before.txt" | tee -a "$LOG_FILE" >/dev/null

  log "capturing ARP while node-a resolves node-b"
  docker exec "$A" rm -f /tmp/arp.pcap >/dev/null 2>&1 || true
  docker exec -d "$A" tcpdump -i eth1 -n -e -s0 -w /tmp/arp.pcap "arp"
  sleep 1
  docker exec "$A" ping -c2 -W2 "$B_IP" 2>&1 | tee "$RUN_DIR/ping.txt" | tee -a "$LOG_FILE" >/dev/null
  sleep 1
  docker exec "$A" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1

  docker cp "$A:/tmp/arp.pcap" "$RUN_DIR/arp.pcap" >/dev/null 2>&1 || true
  docker exec "$A" tcpdump -n -e -vv -r /tmp/arp.pcap 2>/dev/null \
    | tee "$RUN_DIR/arp-decoded.txt" >/dev/null || true
  docker exec "$A" ip neigh show dev eth1 | tee "$RUN_DIR/arp-after.txt" | tee -a "$LOG_FILE" >/dev/null

  log "checking address resolution"
  # The ping worked.
  grep -qE "2 (packets )?received|0% packet loss" "$RUN_DIR/ping.txt"
  # An ARP request and reply were exchanged.
  grep -qiE "Request who-has $B_IP|ARP, Request who-has $B_IP" "$RUN_DIR/arp-decoded.txt"
  grep -qiE "Reply $B_IP is-at" "$RUN_DIR/arp-decoded.txt"
  # The request was broadcast (ff:ff:ff:ff:ff:ff).
  grep -qi "ff:ff:ff:ff:ff:ff" "$RUN_DIR/arp-decoded.txt"
  # After resolution, node-b is in the ARP table with a MAC.
  grep -qiE "$B_IP .*lladdr" "$RUN_DIR/arp-after.txt"

  write_verification "verified" "ARP: with the cache cleared, node-a resolved $B_IP by broadcasting an ARP request ('who has $B_IP') to ff:ff:ff:ff:ff:ff and receiving an ARP reply with node-b's MAC; the ARP table then held node-b's lladdr. This is the IPv4 original that IPv6 NDP (Lab 23) replaced with multicast."
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
