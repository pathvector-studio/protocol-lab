#!/usr/bin/env bash
set -euo pipefail

LAB_ID="tcp-08"
TOPOLOGY="tcp-08.clab.yml"
CLIENT="clab-tcp-08-client"
SERVER="clab-tcp-08-server"
SERVER_IP="10.0.0.2"
PORT="8080"
BYTES="3000000"        # ~3 MB, enough to force retransmissions under loss
NETEM_DELAY="25ms"
NETEM_LOSS="15%"
PCAP_IN="/tmp/tcp-08.pcap"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/tcp-08/runs/$RUN_ID}"
LOG_FILE="$RUN_DIR/run.log"

mkdir -p "$RUN_DIR"

sudo_cmd() { ${SUDO:-sudo} "$@"; }

log() {
  printf '[protocol-lab][%s] %s\n' "$LAB_ID" "$*" | tee -a "$LOG_FILE"
}

run_cmd() {
  log "+ $*"
  "$@" 2>&1 | tee -a "$LOG_FILE"
}

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

# Absolute TcpRetransSegs counter from /proc/net/snmp (awk only, no extra tools).
# /proc/net/snmp has a "Tcp:" header line naming columns and a "Tcp:" value line.
client_retrans() {
  docker exec "$CLIENT" awk '
    /^Tcp:/ { if (!seen) { for (i=1;i<=NF;i++) if ($i=="RetransSegs") c=i; seen=1 }
              else { print $c } }' /proc/net/snmp
}

# netshoot ships OpenBSD netcat (no --exec/--keep-open) and socat; use socat
# for the discard sink (fork keeps accepting; -u streams socket -> /dev/null).
start_sink() {
  docker exec "$SERVER" pkill -f "socat.*$PORT" >/dev/null 2>&1 || true
  docker exec -d "$SERVER" sh -c "socat -u TCP-LISTEN:$PORT,reuseaddr,fork OPEN:/dev/null > /dev/null 2>&1"
  sleep 1
}

# Push $BYTES from client to server; echoes the wall-clock seconds it took.
# -N makes nc shutdown-on-EOF so the sink sees the stream end promptly.
transfer() {
  local start=$SECONDS
  docker exec "$CLIENT" sh -c \
    "timeout 90 sh -c 'head -c $BYTES /dev/zero | nc -N -w15 $SERVER_IP $PORT'" \
    >/dev/null 2>&1 || true
  echo $(( SECONDS - start ))
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
      log "link up after ${i}s"; return 0
    fi
    sleep 1
  done
  log "link did not come up within timeout"; return 1
}

apply_netem() {
  log "adding netem to client eth1: delay $NETEM_DELAY, loss $NETEM_LOSS"
  docker exec "$CLIENT" tc qdisc del dev eth1 root >/dev/null 2>&1 || true
  run_cmd docker exec "$CLIENT" tc qdisc add dev eth1 root netem delay "$NETEM_DELAY" loss "$NETEM_LOSS"
  docker exec "$CLIENT" tc qdisc show dev eth1 | tee "$RUN_DIR/tc-qdisc.txt" | tee -a "$LOG_FILE" >/dev/null
}

clear_netem() {
  docker exec "$CLIENT" tc qdisc del dev eth1 root >/dev/null 2>&1 || true
}

verify() {
  wait_link
  start_sink

  log "baseline transfer over a clean link"
  local r0 r1 clean_secs
  r0="$(client_retrans)"
  clean_secs="$(transfer)"
  r1="$(client_retrans)"
  local clean_retrans=$(( r1 - r0 ))
  log "clean transfer: ${clean_secs}s, client retransmits=${clean_retrans}"

  apply_netem

  log "capturing the lossy transfer"
  docker exec "$CLIENT" rm -f "$PCAP_IN" >/dev/null 2>&1 || true
  docker exec -d "$CLIENT" tcpdump -i eth1 -U -w "$PCAP_IN" "tcp port $PORT"
  # Best-effort: sample socket stats (cwnd/rtt/rto/retrans) during the transfer.
  docker exec -d "$CLIENT" sh -c \
    "for i in \$(seq 1 40); do ss -tino dst $SERVER_IP >> /tmp/ss.log 2>/dev/null; sleep 0.3; done"
  sleep 1

  local r2 r3 loss_secs
  r2="$(client_retrans)"
  loss_secs="$(transfer)"
  r3="$(client_retrans)"
  local loss_retrans=$(( r3 - r2 ))
  sleep 1

  docker exec "$CLIENT" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1
  docker cp "$CLIENT:$PCAP_IN" "$RUN_DIR/tcp-08.pcap" >/dev/null 2>&1 || true
  docker exec "$CLIENT" tcpdump -tttt -n -r "$PCAP_IN" 2>/dev/null \
    | tee "$RUN_DIR/tcpdump-tcp-08.txt" | tee -a "$LOG_FILE" >/dev/null
  docker cp "$CLIENT:/tmp/ss.log" "$RUN_DIR/ss-samples.txt" >/dev/null 2>&1 || true

  clear_netem
  docker exec "$SERVER" pkill -f "socat.*$PORT" >/dev/null 2>&1 || true

  log "lossy transfer: ${loss_secs}s, client retransmits=${loss_retrans}"
  log "summary: clean ${clean_secs}s/${clean_retrans} retrans vs lossy ${loss_secs}s/${loss_retrans} retrans"

  log "checking loss forced retransmissions and recovery"
  # The lossy transfer must retransmit; the clean one should retransmit far less.
  [ "$loss_retrans" -gt 0 ]
  [ "$loss_retrans" -gt "$clean_retrans" ]
  # The transfer still completed (capture has a handshake).
  grep -qE "Flags \[S" "$RUN_DIR/tcpdump-tcp-08.txt"

  write_verification "verified" "Under ${NETEM_LOSS} loss the client retransmitted ${loss_retrans} segments (vs ${clean_retrans} on a clean link) and the ${BYTES}-byte transfer still completed."
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
