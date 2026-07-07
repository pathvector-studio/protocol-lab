#!/usr/bin/env bash
set -euo pipefail

LAB_ID="qos-28"
TOPOLOGY="qos-28.clab.yml"
CLIENT="clab-qos-28-client"
SERVER="clab-qos-28-server"
SERVER_IP="10.0.0.2"
RATE_MBIT="10"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/qos-28/runs/$RUN_ID}"
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

start_iperf() {
  docker exec "$SERVER" pkill -f "iperf3 -s" >/dev/null 2>&1 || true
  log "starting iperf3 server"
  docker exec -d "$SERVER" sh -c "iperf3 -s >/tmp/iperf.log 2>&1"
  sleep 1
}

wait_ready() {
  log "waiting for the link"
  local i
  for i in $(seq 1 30); do
    if docker exec "$CLIENT" ping -c1 -W1 "$SERVER_IP" >/dev/null 2>&1; then
      log "link up after ${i}s"
      return 0
    fi
    sleep 1
  done
  return 1
}

# Run iperf3 and echo the receiver's Mbit/s (integer).
throughput_mbit() {
  local out
  out="$(docker exec "$CLIENT" iperf3 -c "$SERVER_IP" -t 4 -J 2>/dev/null || true)"
  printf '%s' "$out" | jq -r 'try (.end.sum_received.bits_per_second / 1000000 | floor) catch 0'
}

verify() {
  start_iperf
  wait_ready

  log "baseline throughput (no shaping)"
  local base
  base="$(throughput_mbit)"
  echo "baseline: ${base} Mbit/s" | tee "$RUN_DIR/throughput.txt" | tee -a "$LOG_FILE" >/dev/null
  log "baseline: ${base} Mbit/s"

  log "attaching a tc tbf shaper on the client egress: rate ${RATE_MBIT}mbit"
  docker exec "$CLIENT" tc qdisc del dev eth1 root >/dev/null 2>&1 || true
  # burst is in BYTES here (32kb = 32 kilobytes); a bit-sized burst (e.g. 32kbit
  # = 4 KB) is far too small for 10mbit and throttles almost to zero.
  run_cmd docker exec "$CLIENT" tc qdisc add dev eth1 root tbf rate "${RATE_MBIT}mbit" burst 32kb latency 100ms
  docker exec "$CLIENT" tc -s qdisc show dev eth1 | tee "$RUN_DIR/tc-qdisc.txt" | tee -a "$LOG_FILE" >/dev/null

  log "shaped throughput (limited to ~${RATE_MBIT}mbit)"
  local shaped
  shaped="$(throughput_mbit)"
  echo "shaped: ${shaped} Mbit/s" | tee -a "$RUN_DIR/throughput.txt" | tee -a "$LOG_FILE" >/dev/null
  log "shaped: ${shaped} Mbit/s"

  log "removing the shaper"
  docker exec "$CLIENT" tc qdisc del dev eth1 root >/dev/null 2>&1 || true

  docker exec "$SERVER" pkill -f "iperf3 -s" >/dev/null 2>&1 || true

  log "checking the shaper took effect"
  # Baseline is well above the cap (native veth speed).
  [ "${base:-0}" -gt "$((RATE_MBIT * 3))" ]
  # Shaped throughput is near the configured rate (allow tbf overhead/margin).
  [ "${shaped:-0}" -ge "$((RATE_MBIT / 2))" ]
  [ "${shaped:-0}" -le "$((RATE_MBIT * 2))" ]
  # And clearly lower than the unshaped baseline.
  [ "${shaped:-0}" -lt "${base:-0}" ]

  write_verification "verified" "Traffic shaping: baseline iperf3 throughput was ${base} Mbit/s; a tc tbf qdisc capping the client egress at ${RATE_MBIT}mbit dropped it to ${shaped} Mbit/s (near the configured rate, far below the native speed)."
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
