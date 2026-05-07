#!/usr/bin/env bash
set -euo pipefail

LAB_ID="bgp-01"
TOPOLOGY="bgp-01.clab.yml"
R1="clab-bgp-01-r1"
R2="clab-bgp-01-r2"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/bgp-01/runs/$RUN_ID}"
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

wait_bgp() {
  log "waiting for BGP route on r2"
  local i
  for i in $(seq 1 30); do
    if docker exec "$R2" vtysh -c "show bgp ipv4 unicast" 2>/dev/null | grep -q "203.0.113.0/24"; then
      log "BGP route appeared after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "BGP route did not appear within timeout"
  return 1
}

verify() {
  log "collecting FRR output"
  docker exec "$R1" vtysh -c "show bgp summary" | tee "$RUN_DIR/show-bgp-summary-r1.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$R2" vtysh -c "show bgp summary" | tee "$RUN_DIR/show-bgp-summary-r2.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$R2" vtysh -c "show bgp ipv4 unicast" | tee "$RUN_DIR/show-bgp-ipv4-r2.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$R2" vtysh -c "show bgp ipv4 unicast 203.0.113.0/24" | tee "$RUN_DIR/show-bgp-route-203.0.113.0_24-r2.txt" | tee -a "$LOG_FILE" >/dev/null

  log "checking expected fields"
  grep -q "10.0.0.1" "$RUN_DIR/show-bgp-summary-r2.txt"
  grep -q "65001" "$RUN_DIR/show-bgp-summary-r2.txt"
  grep -q "203.0.113.0/24" "$RUN_DIR/show-bgp-ipv4-r2.txt"
  grep -q "10.0.0.1" "$RUN_DIR/show-bgp-ipv4-r2.txt"
  grep -q "65001" "$RUN_DIR/show-bgp-ipv4-r2.txt"
  grep -Eq '(^|[[:space:]])i($|[[:space:]])|IGP' "$RUN_DIR/show-bgp-route-203.0.113.0_24-r2.txt" "$RUN_DIR/show-bgp-ipv4-r2.txt"

  write_verification "verified" "BGP route 203.0.113.0/24 is visible on r2 with next-hop 10.0.0.1 and AS_PATH 65001."
  log "verification OK"
}

capture() {
  log "capturing BGP packets"
  sudo_cmd /usr/sbin/ip netns list | grep -q "clab-bgp-01-r2"

  local pcap="$RUN_DIR/bgp-01-r2.pcap"
  local tshark_summary="$RUN_DIR/tshark-bgp-summary.txt"

  sudo_cmd /usr/sbin/ip netns exec clab-bgp-01-r2 \
    /usr/bin/tcpdump -i eth1 -nn -s 0 -U -w "$pcap" tcp port 179 >>"$LOG_FILE" 2>&1 &
  local tcpdump_pid=$!
  sleep 2

  log "resetting BGP session to force OPEN/UPDATE packets"
  docker exec "$R1" vtysh -c "clear bgp 10.0.0.2" >>"$LOG_FILE" 2>&1 || true
  sleep 10

  kill "$tcpdump_pid" >/dev/null 2>&1 || true
  wait "$tcpdump_pid" >/dev/null 2>&1 || true

  if [[ ! -s "$pcap" ]]; then
    write_verification "failed" "pcap was not created or is empty."
    log "ERROR: pcap is empty"
    return 1
  fi

  tshark -r "$pcap" -Y bgp -T fields -e frame.number -e ip.src -e ip.dst -e bgp.type >"$tshark_summary" || true
  if [[ ! -s "$tshark_summary" ]]; then
    write_verification "failed" "tshark did not find BGP packets in pcap."
    log "ERROR: tshark did not find BGP packets"
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
    wait_bgp
    verify
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
    wait_bgp
    verify
    capture
    log "run complete: $RUN_DIR"
    ;;
  *)
    echo "Usage: $0 {run|deploy|verify|capture|destroy|doctor}" >&2
    exit 1
    ;;
esac
