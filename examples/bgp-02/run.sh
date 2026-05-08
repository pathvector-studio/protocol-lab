#!/usr/bin/env bash
set -euo pipefail

LAB_ID="bgp-02"
TOPOLOGY="bgp-02.clab.yml"
R1="clab-bgp-02-r1"
R2="clab-bgp-02-r2"
PREFIX="203.0.113.0/24"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/bgp-02/runs/$RUN_ID}"
LOG_FILE="$RUN_DIR/run.log"

mkdir -p "$RUN_DIR"

sudo_cmd() {
  ${SUDO:-sudo} "$@"
}

log() {
  printf '[protocol-lab][%s] %s\n' "$LAB_ID" "$*" | tee -a "$LOG_FILE"
}

run_cmd() {
  log "+ $*"
  "$@" 2>&1 | tee -a "$LOG_FILE"
}

json_escape() {
  printf '%s' "$1" | jq -Rs .
}

write_verification() {
  local status="$1"
  local message="$2"
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

has_route() {
  docker exec "$R2" vtysh -c "show bgp ipv4 unicast" 2>/dev/null | grep -q "$PREFIX"
}

wait_route_present() {
  local label="$1"
  log "waiting for BGP route on r2: $label"
  local i
  for i in $(seq 1 30); do
    if has_route; then
      log "BGP route present after ${i}s: $label"
      return 0
    fi
    sleep 1
  done
  log "BGP route did not appear within timeout: $label"
  return 1
}

wait_route_absent() {
  local label="$1"
  log "waiting for BGP route withdrawal on r2: $label"
  local i
  for i in $(seq 1 30); do
    if ! has_route; then
      log "BGP route absent after ${i}s: $label"
      return 0
    fi
    sleep 1
  done
  log "BGP route did not disappear within timeout: $label"
  return 1
}

show_r2_route() {
  local label="$1"
  docker exec "$R2" vtysh -c "show bgp ipv4 unicast" \
    | tee "$RUN_DIR/show-bgp-ipv4-r2-$label.txt" \
    | tee -a "$LOG_FILE" >/dev/null
}

withdraw_route() {
  log "withdrawing $PREFIX from r1"
  docker exec "$R1" vtysh \
    -c "configure terminal" \
    -c "router bgp 65001" \
    -c "address-family ipv4 unicast" \
    -c "no network $PREFIX" >>"$LOG_FILE" 2>&1
}

announce_route() {
  log "announcing $PREFIX from r1"
  docker exec "$R1" vtysh \
    -c "configure terminal" \
    -c "router bgp 65001" \
    -c "address-family ipv4 unicast" \
    -c "network $PREFIX" >>"$LOG_FILE" 2>&1
}

verify_cycle() {
  wait_route_present "before withdraw"
  show_r2_route "before-withdraw"
  grep -q "$PREFIX" "$RUN_DIR/show-bgp-ipv4-r2-before-withdraw.txt"

  withdraw_route
  wait_route_absent "after withdraw"
  show_r2_route "after-withdraw"
  if grep -q "$PREFIX" "$RUN_DIR/show-bgp-ipv4-r2-after-withdraw.txt"; then
    write_verification "failed" "BGP route $PREFIX was still visible on r2 after withdrawal."
    log "ERROR: route still visible after withdrawal"
    return 1
  fi

  announce_route
  wait_route_present "after reannounce"
  show_r2_route "after-reannounce"
  grep -q "$PREFIX" "$RUN_DIR/show-bgp-ipv4-r2-after-reannounce.txt"

  write_verification "verified" "BGP route $PREFIX appeared, was withdrawn, and appeared again on r2."
  log "verification OK"
}

capture() {
  log "capturing announce, withdraw, and reannounce UPDATE packets"
  sudo_cmd /usr/sbin/ip netns list | grep -q "clab-bgp-02-r2"

  local pcap="$RUN_DIR/bgp-02-r2.pcap"
  local tshark_summary="$RUN_DIR/tshark-bgp-update-summary.txt"

  sudo_cmd /usr/sbin/ip netns exec clab-bgp-02-r2 \
    /usr/bin/tcpdump -i eth1 -nn -s 0 -U -w "$pcap" tcp port 179 >>"$LOG_FILE" 2>&1 &
  local tcpdump_pid=$!
  sleep 2

  withdraw_route
  wait_route_absent "capture withdraw"
  sleep 2

  announce_route
  wait_route_present "capture reannounce"
  sleep 5

  kill "$tcpdump_pid" >/dev/null 2>&1 || true
  wait "$tcpdump_pid" >/dev/null 2>&1 || true

  if [[ ! -s "$pcap" ]]; then
    write_verification "failed" "pcap was not created or is empty."
    log "ERROR: pcap is empty"
    return 1
  fi

  tshark -r "$pcap" -Y "bgp.type == 2" -T fields \
    -e frame.number -e ip.src -e ip.dst -e bgp.type >"$tshark_summary" || true
  if [[ ! -s "$tshark_summary" ]]; then
    write_verification "failed" "tshark did not find BGP UPDATE packets in pcap."
    log "ERROR: tshark did not find BGP UPDATE packets"
    return 1
  fi

  log "capture OK: $pcap"
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
  command -v tshark
  sudo_cmd /usr/sbin/ip netns list >/dev/null
}

action="${1:-run}"

case "$action" in
  deploy)
    deploy
    ;;
  verify)
    verify_cycle
    ;;
  capture)
    capture
    ;;
  destroy)
    destroy
    ;;
  doctor)
    doctor
    ;;
  run)
    trap destroy EXIT
    deploy
    verify_cycle
    capture
    log "run complete: $RUN_DIR"
    ;;
  *)
    echo "Usage: $0 {run|deploy|verify|capture|destroy|doctor}" >&2
    exit 1
    ;;
esac
