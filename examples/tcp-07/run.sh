#!/usr/bin/env bash
set -euo pipefail

LAB_ID="tcp-07"
TOPOLOGY="tcp-07.clab.yml"
CLIENT="clab-tcp-07-client"
SERVER="clab-tcp-07-server"
SERVER_IP="10.0.0.2"
PORT="8080"
PCAP_IN="/tmp/tcp-07.pcap"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/tcp-07/runs/$RUN_ID}"
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

wait_link() {
  log "waiting for the client to reach the server"
  local i
  for i in $(seq 1 30); do
    if docker exec "$CLIENT" ping -c1 -W1 "$SERVER_IP" >/dev/null 2>&1; then
      log "link up after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "link did not come up within timeout"
  return 1
}

verify() {
  wait_link

  log "starting an echo listener on the server (:$PORT)"
  docker exec "$SERVER" pkill -f "ncat.*$PORT" >/dev/null 2>&1 || true
  docker exec -d "$SERVER" ncat --listen --keep-open "$PORT" --exec "/bin/cat"
  sleep 1

  log "starting tcpdump on the client link"
  docker exec "$CLIENT" rm -f "$PCAP_IN" >/dev/null 2>&1 || true
  docker exec -d "$CLIENT" tcpdump -i eth1 -U -w "$PCAP_IN" "tcp port $PORT"
  sleep 1

  log "opening one connection: send a line, read the echo, then close"
  docker exec "$CLIENT" sh -c "printf 'hello-tcp\n' | ncat -w2 $SERVER_IP $PORT" \
    | tee "$RUN_DIR/ncat-client.txt" | tee -a "$LOG_FILE" >/dev/null
  sleep 1

  log "stopping capture and collecting output"
  docker exec "$CLIENT" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1
  docker cp "$CLIENT:$PCAP_IN" "$RUN_DIR/tcp-07.pcap" >/dev/null 2>&1 || true
  # Human-readable, absolute-timestamp, no name resolution.
  docker exec "$CLIENT" tcpdump -tttt -n -r "$PCAP_IN" \
    | tee "$RUN_DIR/tcpdump-tcp-07.txt" | tee -a "$LOG_FILE" >/dev/null

  docker exec "$SERVER" pkill -f "ncat.*$PORT" >/dev/null 2>&1 || true

  log "checking the handshake and teardown are visible"
  local cap="$RUN_DIR/tcpdump-tcp-07.txt"
  # SYN, SYN-ACK, and a FIN somewhere in the trace.
  grep -qE "Flags \[S\]," "$cap"
  grep -qE "Flags \[S\.\]," "$cap"
  grep -qE "Flags \[F" "$cap"

  write_verification "verified" "Captured one TCP connection to $SERVER_IP:$PORT showing the SYN / SYN-ACK / ACK handshake and a FIN-based teardown."
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
  deploy)
    deploy
    ;;
  verify)
    verify
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
    verify
    log "run complete: $RUN_DIR"
    ;;
  *)
    echo "Usage: $0 {run|deploy|verify|destroy|doctor}" >&2
    exit 1
    ;;
esac
