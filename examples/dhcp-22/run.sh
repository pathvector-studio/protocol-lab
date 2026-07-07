#!/usr/bin/env bash
set -euo pipefail

LAB_ID="dhcp-22"
TOPOLOGY="dhcp-22.clab.yml"
CLIENT="clab-dhcp-22-client"
SERVER="clab-dhcp-22-server"
POOL_START="10.0.0.100"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/dhcp-22/runs/$RUN_ID}"
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
  log "starting the DHCP server (udhcpd) on the server node"
  docker exec "$SERVER" pkill -f udhcpd >/dev/null 2>&1 || true
  docker exec "$SERVER" sh -c ": > /tmp/udhcpd.leases; udhcpd -f /etc/udhcpd.conf >/tmp/udhcpd.log 2>&1 &"
  sleep 1
}

verify() {
  start_server

  log "capturing the DHCP exchange on the client link (ports 67/68)"
  docker exec "$CLIENT" rm -f /tmp/dhcp.pcap >/dev/null 2>&1 || true
  docker exec -d "$CLIENT" tcpdump -i eth1 -n -s0 -w /tmp/dhcp.pcap "udp port 67 or udp port 68"
  sleep 1

  log "client asks for an address (udhcpc): Discover -> Offer -> Request -> Ack"
  # -q: quit after obtaining a lease; -f: foreground; -n: give up if none.
  docker exec "$CLIENT" sh -c "udhcpc -i eth1 -q -f -n -t 5 2>&1" \
    | tee "$RUN_DIR/udhcpc.txt" | tee -a "$LOG_FILE" >/dev/null || true
  sleep 1

  docker exec "$CLIENT" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1
  docker cp "$CLIENT:/tmp/dhcp.pcap" "$RUN_DIR/dhcp.pcap" >/dev/null 2>&1 || true
  # Decode the DORA exchange.
  docker exec "$CLIENT" tcpdump -n -vv -r /tmp/dhcp.pcap 2>/dev/null \
    | tee "$RUN_DIR/dhcp-decoded.txt" >/dev/null || true
  # What address did the client end up with?
  docker exec "$CLIENT" ip -4 addr show eth1 | tee "$RUN_DIR/client-eth1.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$SERVER" cat /tmp/udhcpd.leases >/dev/null 2>&1 || true
  docker cp "$SERVER:/tmp/udhcpd.log" "$RUN_DIR/udhcpd.log" >/dev/null 2>&1 || true

  log "checking the DORA exchange and the assigned lease"
  # The client obtained an address from the pool (10.0.0.1xx).
  grep -qE "inet 10\.0\.0\.(1[0-9][0-9]|200)" "$RUN_DIR/client-eth1.txt"
  # All four DHCP message types appear on the wire.
  grep -qi "Discover" "$RUN_DIR/dhcp-decoded.txt"
  grep -qi "Offer" "$RUN_DIR/dhcp-decoded.txt"
  grep -qi "Request" "$RUN_DIR/dhcp-decoded.txt"
  grep -qiE "ACK" "$RUN_DIR/dhcp-decoded.txt"

  local addr
  addr="$(grep -oE 'inet 10\.0\.0\.[0-9]+' "$RUN_DIR/client-eth1.txt" | awk '{print $2}' | head -1)"
  write_verification "verified" "DHCP: the client obtained $addr from the server's pool (starting $POOL_START) via the four-message DORA exchange (Discover, Offer, Request, Ack), all captured on the wire."
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
