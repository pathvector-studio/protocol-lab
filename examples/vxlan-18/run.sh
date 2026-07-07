#!/usr/bin/env bash
set -euo pipefail

LAB_ID="vxlan-18"
TOPOLOGY="vxlan-18.clab.yml"
A="clab-vxlan-18-node-a"
B="clab-vxlan-18-node-b"
A_UNDER="10.0.0.1"
B_UNDER="10.0.0.2"
A_OVL="10.200.0.1"
B_OVL="10.200.0.2"
VNI="100"
VXPORT="4789"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/vxlan-18/runs/$RUN_ID}"
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

setup_overlay() {
  # Point-to-point VXLAN: each node's vxlan0 forwards to the peer's underlay
  # address. VNI 100 identifies the overlay; UDP 4789 is the VXLAN port. The
  # host kernel vxlan module autoloads when the first vxlan interface is made.
  log "building the VXLAN overlay (VNI $VNI, UDP $VXPORT)"
  docker exec "$A" sh -c \
    "ip link add vxlan0 type vxlan id $VNI remote $B_UNDER dstport $VXPORT dev eth1; \
     ip addr add $A_OVL/24 dev vxlan0; ip link set vxlan0 up"
  docker exec "$B" sh -c \
    "ip link add vxlan0 type vxlan id $VNI remote $A_UNDER dstport $VXPORT dev eth1; \
     ip addr add $B_OVL/24 dev vxlan0; ip link set vxlan0 up"
}

wait_overlay() {
  log "waiting for the overlay to carry traffic ($A_OVL -> $B_OVL)"
  local i
  for i in $(seq 1 30); do
    if docker exec "$A" ping -c1 -W1 "$B_OVL" >/dev/null 2>&1; then
      log "overlay up after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "overlay did not come up within timeout"
  return 1
}

verify() {
  setup_overlay
  wait_overlay

  log "capturing the underlay (eth1) during a ping across the overlay"
  docker exec "$A" rm -f /tmp/vx.pcap >/dev/null 2>&1 || true
  docker exec -d "$A" tcpdump -i eth1 -n -w /tmp/vx.pcap "udp port $VXPORT"
  sleep 1
  docker exec "$A" ping -c3 -W2 "$B_OVL" 2>&1 | tee "$RUN_DIR/ping.txt" | tee -a "$LOG_FILE" >/dev/null
  sleep 1
  docker exec "$A" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1

  docker cp "$A:/tmp/vx.pcap" "$RUN_DIR/underlay.pcap" >/dev/null 2>&1 || true
  # Decode the capture: VXLAN header + the inner frame (visible: no encryption).
  docker exec "$A" tcpdump -n -e -vv -r /tmp/vx.pcap 2>/dev/null \
    | tee "$RUN_DIR/underlay-decoded.txt" >/dev/null || true
  docker exec "$A" ip -d link show vxlan0 | tee "$RUN_DIR/vxlan-link.txt" | tee -a "$LOG_FILE" >/dev/null

  log "checking the overlay and what the underlay reveals"
  # The overlay ping worked.
  grep -qE "3 (packets )?received|0% packet loss" "$RUN_DIR/ping.txt"
  # The underlay carries VXLAN with our VNI.
  grep -qi "VXLAN" "$RUN_DIR/underlay-decoded.txt"
  grep -qiE "vni $VNI" "$RUN_DIR/underlay-decoded.txt"
  # And because VXLAN is not encrypted, the inner ICMP is visible on the underlay.
  grep -qi "ICMP echo" "$RUN_DIR/underlay-decoded.txt"

  write_verification "verified" "VXLAN overlay (VNI $VNI) up between $A_OVL and $B_OVL; a ping across it succeeded. On the underlay the packets are VXLAN over UDP/$VXPORT, and because VXLAN does not encrypt, the inner ICMP echo is visible in the clear (unlike the WireGuard tunnel in Lab 16)."
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
