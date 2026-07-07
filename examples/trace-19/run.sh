#!/usr/bin/env bash
set -euo pipefail

LAB_ID="trace-19"
TOPOLOGY="trace-19.clab.yml"
CLIENT="clab-trace-19-client"
R1="clab-trace-19-r1"
R2="clab-trace-19-r2"
SERVER="clab-trace-19-server"
SERVER_IP="10.0.3.2"
R1_HOP="10.0.1.2"
R2_HOP="10.0.2.2"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/trace-19/runs/$RUN_ID}"
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
  # r1 and r2 forward; every node gets routes to the far subnets. The client's
  # default route is owned by the management network, so add explicit routes.
  log "enabling forwarding on r1/r2 and adding static routes"
  docker exec "$R1" sysctl -w net.ipv4.ip_forward=1 >/dev/null
  docker exec "$R2" sysctl -w net.ipv4.ip_forward=1 >/dev/null
  # client -> everything beyond r1
  docker exec "$CLIENT" sh -c "ip route add 10.0.2.0/24 via $R1_HOP; ip route add 10.0.3.0/24 via $R1_HOP"
  # r1 -> server subnet via r2
  docker exec "$R1" ip route add 10.0.3.0/24 via 10.0.2.2
  # r2 -> client subnet via r1
  docker exec "$R2" ip route add 10.0.1.0/24 via 10.0.2.1
  # server -> everything back via r2
  docker exec "$SERVER" sh -c "ip route add 10.0.2.0/24 via 10.0.3.1; ip route add 10.0.1.0/24 via 10.0.3.1"
}

wait_path() {
  log "waiting for the end-to-end path (client -> server)"
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

  log "1) traceroute from client to server (each hop = one router)"
  # ICMP-mode traceroute is the most robust across environments.
  docker exec "$CLIENT" traceroute -I -n -q1 -w2 "$SERVER_IP" \
    | tee "$RUN_DIR/traceroute.txt" | tee -a "$LOG_FILE" >/dev/null

  log "2) capturing ICMP time-exceeded replies during a low-TTL probe"
  docker exec "$CLIENT" rm -f /tmp/te.pcap >/dev/null 2>&1 || true
  docker exec -d "$CLIENT" tcpdump -i eth1 -n -w /tmp/te.pcap "icmp"
  sleep 1
  # A ping with TTL 1 dies at r1 -> r1 sends ICMP time-exceeded.
  docker exec "$CLIENT" ping -c1 -W2 -t1 "$SERVER_IP" 2>&1 | tee "$RUN_DIR/ping-ttl1.txt" | tee -a "$LOG_FILE" >/dev/null || true
  # TTL 2 dies at r2.
  docker exec "$CLIENT" ping -c1 -W2 -t2 "$SERVER_IP" 2>&1 | tee -a "$RUN_DIR/ping-ttl1.txt" | tee -a "$LOG_FILE" >/dev/null || true
  sleep 1
  docker exec "$CLIENT" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1
  docker cp "$CLIENT:/tmp/te.pcap" "$RUN_DIR/icmp.pcap" >/dev/null 2>&1 || true
  docker exec "$CLIENT" tcpdump -n -vv -r /tmp/te.pcap 2>/dev/null \
    | tee "$RUN_DIR/icmp-decoded.txt" >/dev/null || true

  log "checking the hops and the TTL mechanism"
  # traceroute revealed r1 then r2 then the server, in order.
  grep -q "$R1_HOP" "$RUN_DIR/traceroute.txt"
  grep -q "$R2_HOP" "$RUN_DIR/traceroute.txt"
  grep -q "$SERVER_IP" "$RUN_DIR/traceroute.txt"
  # The capture shows ICMP time-exceeded (the packet that reveals a hop).
  grep -qi "time exceeded" "$RUN_DIR/icmp-decoded.txt"
  # r1 is the source of the TTL-1 time-exceeded.
  grep -qE "$R1_HOP > .*time exceeded|time exceeded.*$R1_HOP" "$RUN_DIR/icmp-decoded.txt"

  write_verification "verified" "traceroute from the client reached $SERVER_IP via $R1_HOP (r1) then $R2_HOP (r2); a TTL-1 probe drew an ICMP time-exceeded from r1 ($R1_HOP), which is exactly how traceroute maps the path."
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
