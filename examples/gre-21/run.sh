#!/usr/bin/env bash
set -euo pipefail

LAB_ID="gre-21"
TOPOLOGY="gre-21.clab.yml"
A="clab-gre-21-node-a"
B="clab-gre-21-node-b"
A_UNDER="10.0.0.1"
B_UNDER="10.0.0.2"
A_OVL="10.100.0.1"
B_OVL="10.100.0.2"
GREIF="gre1"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/gre-21/runs/$RUN_ID}"
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

setup_tunnel() {
  # Point-to-point GRE. The name gre1 avoids the module's default gre0 device.
  # GRE is a host kernel module (ip_gre); it autoloads when the tunnel is made.
  log "building the GRE tunnel (IP protocol 47)"
  docker exec "$A" sh -c \
    "ip link add $GREIF type gre local $A_UNDER remote $B_UNDER; \
     ip addr add $A_OVL/24 dev $GREIF; ip link set $GREIF up"
  docker exec "$B" sh -c \
    "ip link add $GREIF type gre local $B_UNDER remote $A_UNDER; \
     ip addr add $B_OVL/24 dev $GREIF; ip link set $GREIF up"
}

wait_tunnel() {
  log "waiting for the tunnel to carry traffic ($A_OVL -> $B_OVL)"
  local i
  for i in $(seq 1 30); do
    if docker exec "$A" ping -c1 -W1 "$B_OVL" >/dev/null 2>&1; then
      log "tunnel up after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "tunnel did not come up within timeout"
  return 1
}

verify() {
  setup_tunnel
  wait_tunnel

  log "capturing the underlay (eth1) during a ping across the tunnel"
  docker exec "$A" rm -f /tmp/gre.pcap >/dev/null 2>&1 || true
  # proto 47 = GRE
  docker exec -d "$A" tcpdump -i eth1 -n -w /tmp/gre.pcap "proto 47"
  sleep 1
  docker exec "$A" ping -c3 -W2 "$B_OVL" 2>&1 | tee "$RUN_DIR/ping.txt" | tee -a "$LOG_FILE" >/dev/null
  sleep 1
  docker exec "$A" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1

  docker cp "$A:/tmp/gre.pcap" "$RUN_DIR/underlay.pcap" >/dev/null 2>&1 || true
  # Decode: outer IP (GRE) + the inner IP/ICMP (visible: not encrypted).
  docker exec "$A" tcpdump -n -vv -r /tmp/gre.pcap 2>/dev/null \
    | tee "$RUN_DIR/underlay-decoded.txt" >/dev/null || true
  docker exec "$A" ip -d link show "$GREIF" | tee "$RUN_DIR/gre-link.txt" | tee -a "$LOG_FILE" >/dev/null

  log "checking the tunnel and what the underlay reveals"
  # The overlay ping worked.
  grep -qE "3 (packets )?received|0% packet loss" "$RUN_DIR/ping.txt"
  # The underlay carries GRE.
  grep -qi "GRE" "$RUN_DIR/underlay-decoded.txt"
  # And because GRE is not encrypted, the inner ICMP is visible on the underlay.
  grep -qi "ICMP echo" "$RUN_DIR/underlay-decoded.txt"

  write_verification "verified" "GRE tunnel up between $A_OVL and $B_OVL; a ping across it succeeded. On the underlay the packets are GRE (IP protocol 47), and because GRE does not encrypt, the inner ICMP echo is visible in the clear — an L3 counterpart to VXLAN (Lab 18) and the unencrypted opposite of WireGuard (Lab 16)."
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
