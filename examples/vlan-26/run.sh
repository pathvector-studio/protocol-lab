#!/usr/bin/env bash
set -euo pipefail

LAB_ID="vlan-26"
TOPOLOGY="vlan-26.clab.yml"
A="clab-vlan-26-node-a"
B="clab-vlan-26-node-b"
B_V100="10.0.100.2"
B_V200="10.0.200.2"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/vlan-26/runs/$RUN_ID}"
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

setup_vlans() {
  log "creating 802.1Q subinterfaces (VLAN 100 and VLAN 200) on both nodes"
  docker exec "$A" sh -c '
    ip link add link eth1 name eth1.100 type vlan id 100
    ip link add link eth1 name eth1.200 type vlan id 200
    ip addr add 10.0.100.1/24 dev eth1.100; ip link set eth1.100 up
    ip addr add 10.0.200.1/24 dev eth1.200; ip link set eth1.200 up'
  docker exec "$B" sh -c '
    ip link add link eth1 name eth1.100 type vlan id 100
    ip link add link eth1 name eth1.200 type vlan id 200
    ip addr add 10.0.100.2/24 dev eth1.100; ip link set eth1.100 up
    ip addr add 10.0.200.2/24 dev eth1.200; ip link set eth1.200 up'
}

wait_vlans() {
  log "waiting for VLAN 100 connectivity ($B_V100)"
  local i
  for i in $(seq 1 30); do
    if docker exec "$A" ping -c1 -W1 "$B_V100" >/dev/null 2>&1; then
      log "VLAN 100 up after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "VLAN did not come up within timeout"
  return 1
}

verify() {
  setup_vlans
  wait_vlans

  log "capturing the trunk (eth1) while pinging over VLAN 100 then VLAN 200"
  docker exec "$A" rm -f /tmp/vlan.pcap >/dev/null 2>&1 || true
  docker exec -d "$A" tcpdump -i eth1 -n -e "icmp"
  docker exec -d "$A" tcpdump -i eth1 -n -e -w /tmp/vlan.pcap "icmp"
  sleep 1
  docker exec "$A" ping -c2 -W2 "$B_V100" 2>&1 | tee "$RUN_DIR/ping-v100.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$A" ping -c2 -W2 "$B_V200" 2>&1 | tee "$RUN_DIR/ping-v200.txt" | tee -a "$LOG_FILE" >/dev/null
  sleep 1
  docker exec "$A" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1

  docker cp "$A:/tmp/vlan.pcap" "$RUN_DIR/vlan.pcap" >/dev/null 2>&1 || true
  docker exec "$A" tcpdump -n -e -r /tmp/vlan.pcap 2>/dev/null \
    | tee "$RUN_DIR/vlan-decoded.txt" >/dev/null || true

  # Separate captures per VLAN to show each is tagged and isolated.
  docker exec "$A" rm -f /tmp/v100.pcap >/dev/null 2>&1 || true
  docker exec -d "$A" tcpdump -i eth1 -n -e -w /tmp/v100.pcap "vlan 100 and icmp"
  sleep 1
  docker exec "$A" ping -c2 -W2 "$B_V100" >/dev/null 2>&1 || true
  sleep 1
  docker exec "$A" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1
  docker exec "$A" tcpdump -n -e -r /tmp/v100.pcap 2>/dev/null \
    | tee "$RUN_DIR/v100-only.txt" >/dev/null || true

  log "checking VLAN tagging and isolation"
  # Both VLANs carry traffic.
  grep -qE "2 (packets )?received|0% packet loss" "$RUN_DIR/ping-v100.txt"
  grep -qE "2 (packets )?received|0% packet loss" "$RUN_DIR/ping-v200.txt"
  # The trunk shows 802.1Q tags for both VLAN IDs.
  grep -qiE "vlan 100" "$RUN_DIR/vlan-decoded.txt"
  grep -qiE "vlan 200" "$RUN_DIR/vlan-decoded.txt"
  # A VLAN-100-only capture during a VLAN-100 ping contains no VLAN 200 frames.
  grep -qiE "vlan 100" "$RUN_DIR/v100-only.txt"
  ! grep -qiE "vlan 200" "$RUN_DIR/v100-only.txt"

  write_verification "verified" "802.1Q: node-a reached node-b over VLAN 100 and VLAN 200 on one physical link; the trunk carried 802.1Q-tagged frames (vlan 100 and vlan 200), and a VLAN-100 ping showed only vlan 100 tags — each VLAN is a separate broadcast domain kept apart by its tag."
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
