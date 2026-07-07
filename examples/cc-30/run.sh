#!/usr/bin/env bash
set -euo pipefail

LAB_ID="cc-30"
TOPOLOGY="cc-30.clab.yml"
CLIENT="clab-cc-30-client"
SERVER="clab-cc-30-server"
SERVER_IP="10.0.0.2"
DELAY_MS="50"        # per-direction one-way delay (RTT ~= 100 ms)
LOSS_PCT="2"         # random loss on the data path
RATE_MBIT="100"      # bottleneck rate cap
DURATION="10"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/cc-30/runs/$RUN_ID}"
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

# Run iperf3 with a given congestion control algorithm; echo receiver Mbit/s
# (integer) and stash the JSON + a mid-transfer `ss -ti` snapshot.
run_algo() {
  local algo="$1" out
  # kick off a background transfer so we can sample ss -ti while it runs
  docker exec -d "$CLIENT" sh -c "iperf3 -c $SERVER_IP -C $algo -t $DURATION -J >/tmp/${algo}.json 2>/dev/null"
  sleep $((DURATION / 2))
  docker exec "$CLIENT" sh -c "ss -tin dst $SERVER_IP | tr ',' '\n'" \
    >"$RUN_DIR/ss-${algo}.txt" 2>/dev/null || true
  # wait for the transfer to finish
  local i
  for i in $(seq 1 "$DURATION"); do
    if docker exec "$CLIENT" sh -c "test -s /tmp/${algo}.json && grep -q sum_received /tmp/${algo}.json" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  docker cp "$CLIENT:/tmp/${algo}.json" "$RUN_DIR/${algo}.json" >/dev/null 2>&1 || true
  out="$(docker exec "$CLIENT" cat "/tmp/${algo}.json" 2>/dev/null || true)"
  printf '%s' "$out" | jq -r 'try (.end.sum_received.bits_per_second / 1000000 | floor) catch 0'
}

verify() {
  start_iperf
  wait_ready

  log "impairing the path: ${DELAY_MS}ms each way (RTT ~$((DELAY_MS * 2))ms), ${LOSS_PCT}% loss, ${RATE_MBIT}mbit cap"
  docker exec "$CLIENT" tc qdisc del dev eth1 root >/dev/null 2>&1 || true
  docker exec "$SERVER" tc qdisc del dev eth1 root >/dev/null 2>&1 || true
  # Data path (client egress): delay + random loss + rate cap.
  run_cmd docker exec "$CLIENT" tc qdisc add dev eth1 root netem delay "${DELAY_MS}ms" loss "${LOSS_PCT}%" rate "${RATE_MBIT}mbit"
  # Return path (server egress): matching delay so RTT is symmetric.
  run_cmd docker exec "$SERVER" tc qdisc add dev eth1 root netem delay "${DELAY_MS}ms"

  log "confirming the path RTT"
  docker exec "$CLIENT" ping -c3 -q "$SERVER_IP" 2>&1 | tee "$RUN_DIR/ping.txt" | tee -a "$LOG_FILE" >/dev/null

  log "CUBIC (loss-based) over the lossy path"
  local cubic
  cubic="$(run_algo cubic)"
  echo "cubic: ${cubic} Mbit/s" | tee "$RUN_DIR/throughput.txt" | tee -a "$LOG_FILE" >/dev/null
  log "cubic: ${cubic} Mbit/s"

  log "BBR (model-based) over the same path"
  local bbr
  bbr="$(run_algo bbr)"
  echo "bbr: ${bbr} Mbit/s" | tee -a "$RUN_DIR/throughput.txt" | tee -a "$LOG_FILE" >/dev/null
  log "bbr: ${bbr} Mbit/s"

  log "removing the impairment"
  docker exec "$CLIENT" tc qdisc del dev eth1 root >/dev/null 2>&1 || true
  docker exec "$SERVER" tc qdisc del dev eth1 root >/dev/null 2>&1 || true
  docker exec "$SERVER" pkill -f "iperf3 -s" >/dev/null 2>&1 || true

  log "checking BBR beat CUBIC on the lossy path"
  # Both transfers actually completed.
  [ "${cubic:-0}" -ge 1 ]
  [ "${bbr:-0}" -ge 1 ]
  # CUBIC is loss-limited: well below the rate cap.
  [ "${cubic:-0}" -lt "$RATE_MBIT" ]
  # BBR keeps the pipe far fuller than CUBIC (the whole point of the lab).
  [ "${bbr:-0}" -gt "$((cubic * 2))" ]

  write_verification "verified" "TCP congestion control: over a 100 ms RTT path with ${LOSS_PCT}% random loss and a ${RATE_MBIT}mbit cap, CUBIC (loss-based) measured ${cubic} Mbit/s while BBR (model-based) measured ${bbr} Mbit/s. CUBIC reads random loss as congestion and backs off; BBR models the bottleneck and keeps the pipe near full."
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
