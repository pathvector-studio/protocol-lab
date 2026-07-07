#!/usr/bin/env bash
set -euo pipefail

LAB_ID="mtu-25"
TOPOLOGY="mtu-25.clab.yml"
CLIENT="clab-mtu-25-client"
ROUTER="clab-mtu-25-router"
SERVER="clab-mtu-25-server"
SERVER_IP="10.0.2.2"
NARROW_MTU="1400"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/mtu-25/runs/$RUN_ID}"
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

setup_routing() {
  log "enabling forwarding on the router and adding routes"
  docker exec "$ROUTER" sysctl -w net.ipv4.ip_forward=1 >/dev/null
  docker exec "$CLIENT" ip route add 10.0.2.0/24 via 10.0.1.2
  docker exec "$SERVER" ip route add 10.0.1.0/24 via 10.0.2.1
}

wait_path() {
  log "waiting for the path (client -> server)"
  local i
  for i in $(seq 1 30); do
    if docker exec "$CLIENT" ping -c1 -W1 "$SERVER_IP" >/dev/null 2>&1; then
      log "path up after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "path did not come up within timeout"
  return 1
}

verify() {
  setup_routing
  wait_path

  # Flush any cached PMTU so discovery starts fresh.
  docker exec "$CLIENT" ip route flush cache >/dev/null 2>&1 || true

  log "capturing on the client while sending an oversized DF packet"
  docker exec "$CLIENT" rm -f /tmp/mtu.pcap >/dev/null 2>&1 || true
  docker exec -d "$CLIENT" tcpdump -i eth1 -n -w /tmp/mtu.pcap "icmp"
  sleep 1
  # 1500-byte payload + 28 (ICMP+IP) = 1528 > 1400 narrow link, DF set.
  log "ping -M do -s 1500 (too big for the 1400 link) -> expect Frag needed"
  docker exec "$CLIENT" ping -M do -s 1500 -c1 -W2 "$SERVER_IP" 2>&1 \
    | tee "$RUN_DIR/ping-big.txt" | tee -a "$LOG_FILE" >/dev/null || true
  sleep 1
  docker exec "$CLIENT" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1

  docker cp "$CLIENT:/tmp/mtu.pcap" "$RUN_DIR/icmp.pcap" >/dev/null 2>&1 || true
  docker exec "$CLIENT" tcpdump -n -vv -r /tmp/mtu.pcap 2>/dev/null \
    | tee "$RUN_DIR/icmp-decoded.txt" >/dev/null || true
  # The client should now have cached the path MTU for the server.
  docker exec "$CLIENT" ip route get "$SERVER_IP" | tee "$RUN_DIR/route-get.txt" | tee -a "$LOG_FILE" >/dev/null

  log "a packet that fits (-s 1300) should get through"
  docker exec "$CLIENT" ping -M do -s 1300 -c1 -W2 "$SERVER_IP" 2>&1 \
    | tee "$RUN_DIR/ping-fit.txt" | tee -a "$LOG_FILE" >/dev/null || true

  log "checking Path MTU Discovery"
  # The oversized DF packet was rejected with the router's next-hop MTU.
  grep -qiE "Frag(mentation)? needed|message too long|mtu ?= ?$NARROW_MTU|mtu $NARROW_MTU" "$RUN_DIR/ping-big.txt" "$RUN_DIR/icmp-decoded.txt"
  # The client cached the path MTU (1400) for the server.
  grep -qE "mtu $NARROW_MTU" "$RUN_DIR/route-get.txt"
  # A packet within the path MTU gets through.
  grep -qE "1 (packets )?received|0% packet loss" "$RUN_DIR/ping-fit.txt"

  write_verification "verified" "Path MTU Discovery: a DF-marked 1500-byte packet toward $SERVER_IP was too big for the router's $NARROW_MTU link, so the router returned ICMP fragmentation-needed carrying MTU $NARROW_MTU; the client cached that path MTU (visible in 'ip route get'), and a packet within it got through."
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
