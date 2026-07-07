#!/usr/bin/env bash
set -euo pipefail

LAB_ID="wg-16"
TOPOLOGY="wg-16.clab.yml"
A="clab-wg-16-node-a"
B="clab-wg-16-node-b"
A_UNDER="10.0.0.1"
B_UNDER="10.0.0.2"
A_WG="10.99.0.1"
B_WG="10.99.0.2"
WG_NET="10.99.0.0/24"
PORT="51820"
WG_IMAGE="protocol-lab/wireguard:latest"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/wg-16/runs/$RUN_ID}"
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

build_image() {
  log "building $WG_IMAGE (netshoot + wireguard-tools)"
  run_cmd docker build -t "$WG_IMAGE" "$LAB_DIR"
}

deploy() {
  build_image
  log "deploying topology"
  sudo_cmd containerlab destroy -t "$TOPOLOGY" --cleanup >/dev/null 2>&1 || true
  run_cmd sudo_cmd containerlab deploy -t "$TOPOLOGY"
}

setup_tunnel() {
  # Each end needs the other's public key, so keys are generated and exchanged
  # here at run time (not in the topology file). The WireGuard kernel module on
  # the host autoloads when the first wg0 interface is created.
  log "generating keys and building the WireGuard tunnel"
  local a_priv a_pub b_priv b_pub
  a_priv="$(docker exec "$A" wg genkey)"
  a_pub="$(printf '%s' "$a_priv" | docker exec -i "$A" wg pubkey)"
  b_priv="$(docker exec "$B" wg genkey)"
  b_pub="$(printf '%s' "$b_priv" | docker exec -i "$B" wg pubkey)"

  # Feed the private key on stdin (private-key /dev/stdin) rather than a temp
  # file: wg is blocked from reading /tmp by the container's security profile,
  # and stdin keeps the key off disk anyway.
  docker exec "$A" ip link add wg0 type wireguard
  printf '%s' "$a_priv" | docker exec -i "$A" sh -c \
    "wg set wg0 private-key /dev/stdin listen-port $PORT \
       peer $b_pub endpoint $B_UNDER:$PORT allowed-ips $WG_NET"
  docker exec "$A" sh -c "ip addr add $A_WG/24 dev wg0; ip link set wg0 up"

  docker exec "$B" ip link add wg0 type wireguard
  printf '%s' "$b_priv" | docker exec -i "$B" sh -c \
    "wg set wg0 private-key /dev/stdin listen-port $PORT \
       peer $a_pub endpoint $A_UNDER:$PORT allowed-ips $WG_NET"
  docker exec "$B" sh -c "ip addr add $B_WG/24 dev wg0; ip link set wg0 up"
}

wait_tunnel() {
  log "waiting for the tunnel to carry traffic ($A_WG -> $B_WG)"
  local i
  for i in $(seq 1 30); do
    if docker exec "$A" ping -c1 -W1 "$B_WG" >/dev/null 2>&1; then
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

  local iface="eth1"

  log "capturing the underlay (eth1) and the tunnel interior (wg0) during a ping"
  docker exec "$A" rm -f /tmp/under.pcap /tmp/inner.pcap >/dev/null 2>&1 || true
  docker exec -d "$A" tcpdump -i "$iface" -n -w /tmp/under.pcap "udp port $PORT or icmp"
  docker exec -d "$A" tcpdump -i wg0 -n -w /tmp/inner.pcap "icmp"
  sleep 1
  docker exec "$A" ping -c3 -W2 "$B_WG" 2>&1 | tee "$RUN_DIR/ping.txt" | tee -a "$LOG_FILE" >/dev/null
  sleep 1
  docker exec "$A" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1

  docker cp "$A:/tmp/under.pcap" "$RUN_DIR/underlay.pcap" >/dev/null 2>&1 || true
  docker cp "$A:/tmp/inner.pcap" "$RUN_DIR/inner-wg0.pcap" >/dev/null 2>&1 || true
  docker exec "$A" tcpdump -n -r /tmp/under.pcap 2>/dev/null | tee "$RUN_DIR/underlay.txt" >/dev/null || true
  docker exec "$A" tcpdump -n -r /tmp/inner.pcap 2>/dev/null | tee "$RUN_DIR/inner-wg0.txt" >/dev/null || true
  docker exec "$A" wg show wg0 | tee "$RUN_DIR/wg-show.txt" | tee -a "$LOG_FILE" >/dev/null

  log "checking the tunnel and what it hides"
  # The ping across the tunnel succeeded.
  grep -qE "3 (packets )?received|0% packet loss" "$RUN_DIR/ping.txt"
  # A WireGuard handshake happened (peer + a recent handshake).
  grep -qi "latest handshake" "$RUN_DIR/wg-show.txt"
  # Underlay carries encrypted UDP/51820 ...
  grep -q "$PORT" "$RUN_DIR/underlay.txt"
  # ... and NOT the inner ICMP (it is inside the tunnel).
  ! grep -qi "ICMP echo" "$RUN_DIR/underlay.txt"
  # Inside wg0 the ICMP echo is visible (decrypted).
  grep -qi "ICMP echo" "$RUN_DIR/inner-wg0.txt"

  write_verification "verified" "WireGuard tunnel up between $A_WG and $B_WG; a ping across it succeeded. On the underlay (eth1) only encrypted UDP/$PORT was visible (no inner ICMP); inside wg0 the ICMP echoes were cleartext."
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
