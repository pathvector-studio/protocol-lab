#!/usr/bin/env bash
set -euo pipefail

LAB_ID="nat-20"
TOPOLOGY="nat-20.clab.yml"
CLIENT="clab-nat-20-client"
NAT="clab-nat-20-nat"
SERVER="clab-nat-20-server"
CLIENT_PRIV="192.168.10.1"
NAT_PUB="203.0.113.254"
SERVER_IP="203.0.113.1"
PORT="8080"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/nat-20/runs/$RUN_ID}"
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

setup_nat() {
  log "enabling forwarding + MASQUERADE on the nat node, adding routes"
  docker exec "$NAT" sysctl -w net.ipv4.ip_forward=1 >/dev/null
  # Source-NAT (masquerade) outbound packets leaving the public interface.
  docker exec "$NAT" iptables -t nat -A POSTROUTING -o eth2 -j MASQUERADE
  # Client reaches the public network through the nat.
  docker exec "$CLIENT" ip route add 203.0.113.0/24 via 192.168.10.254
  # The server needs NO route to the private net — that is the point of NAT.
}

start_server() {
  docker exec "$SERVER" pkill -f "http.server" >/dev/null 2>&1 || true
  log "starting a small HTTP server on $SERVER_IP:$PORT"
  docker exec -d "$SERVER" sh -c "cd /tmp && python3 -m http.server $PORT >/tmp/http.log 2>&1"
  sleep 1
}

wait_ready() {
  log "waiting for the client to reach the server through the nat"
  local i
  for i in $(seq 1 30); do
    if docker exec "$CLIENT" curl -s -o /dev/null "http://$SERVER_IP:$PORT/" 2>/dev/null; then
      log "reachable after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "server not reachable within timeout"
  return 1
}

verify() {
  setup_nat
  start_server
  wait_ready

  log "capturing the server side while the client makes a request"
  docker exec "$SERVER" rm -f /tmp/srv.pcap >/dev/null 2>&1 || true
  docker exec -d "$SERVER" tcpdump -i eth1 -n -w /tmp/srv.pcap "tcp port $PORT"
  sleep 1
  docker exec "$CLIENT" curl -s -o /dev/null -w "client got HTTP %{http_code}\n" "http://$SERVER_IP:$PORT/" \
    | tee "$RUN_DIR/client-curl.txt" | tee -a "$LOG_FILE" >/dev/null
  sleep 1
  docker exec "$SERVER" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1

  docker cp "$SERVER:/tmp/srv.pcap" "$RUN_DIR/server-side.pcap" >/dev/null 2>&1 || true
  docker exec "$SERVER" tcpdump -n -r /tmp/srv.pcap 2>/dev/null \
    | tee "$RUN_DIR/server-side.txt" >/dev/null || true
  # The server's own log records the peer address it saw.
  docker exec "$SERVER" cat /tmp/http.log 2>/dev/null | tee "$RUN_DIR/server-http.log" >/dev/null || true
  # The NAT's connection-tracking table shows the translation.
  docker exec "$NAT" conntrack -L 2>/dev/null | grep "$PORT" \
    | tee "$RUN_DIR/conntrack.txt" >/dev/null || true

  log "checking the source translation"
  # The request succeeded.
  grep -q "HTTP 200" "$RUN_DIR/client-curl.txt"
  # On the public side the connection comes from the NAT's public address ...
  grep -q "$NAT_PUB" "$RUN_DIR/server-side.txt"
  # ... and the client's private address is NOT visible there.
  ! grep -q "$CLIENT_PRIV" "$RUN_DIR/server-side.txt"
  # conntrack recorded the mapping (private client -> public).
  grep -q "$CLIENT_PRIV" "$RUN_DIR/conntrack.txt"
  grep -q "$NAT_PUB" "$RUN_DIR/conntrack.txt"

  write_verification "verified" "Source NAT: the client ($CLIENT_PRIV, private) reached the server, which saw the connection from the NAT's public address $NAT_PUB (the private address never appears on the public side). The NAT's conntrack table records the $CLIENT_PRIV -> $NAT_PUB translation."
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
