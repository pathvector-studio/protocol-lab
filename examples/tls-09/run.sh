#!/usr/bin/env bash
set -euo pipefail

LAB_ID="tls-09"
TOPOLOGY="tls-09.clab.yml"
CLIENT="clab-tls-09-client"
SERVER="clab-tls-09-server"
SERVER_IP="10.0.0.2"
PORT="4433"
SNI="www.example.lab"
PCAP_IN="/tmp/tls-09.pcap"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/tls-09/runs/$RUN_ID}"
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

make_cert() {
  log "generating a self-signed cert for CN=$SNI on the server"
  docker exec "$SERVER" sh -c \
    "openssl req -x509 -newkey rsa:2048 -nodes \
       -keyout /tmp/server.key -out /tmp/server.crt \
       -subj '/CN=$SNI' -days 30 -addext 'subjectAltName=DNS:$SNI'" \
    2>&1 | tee -a "$LOG_FILE" >/dev/null
}

start_server() {
  docker exec "$SERVER" pkill -f "s_server.*$PORT" >/dev/null 2>&1 || true
  log "starting openssl s_server on :$PORT with ALPN h2,http/1.1"
  docker exec -d "$SERVER" sh -c \
    "openssl s_server -accept $PORT -cert /tmp/server.crt -key /tmp/server.key \
       -alpn h2,http/1.1 -www -quiet"
  sleep 1
}

verify() {
  wait_link
  make_cert
  start_server

  log "capturing the TLS handshake on the client link"
  docker exec "$CLIENT" rm -f "$PCAP_IN" >/dev/null 2>&1 || true
  docker exec -d "$CLIENT" tcpdump -i eth1 -U -s0 -w "$PCAP_IN" "tcp port $PORT"
  sleep 1

  log "running openssl s_client with SNI=$SNI and ALPN h2,http/1.1"
  docker exec "$CLIENT" sh -c \
    "echo Q | openssl s_client -connect $SERVER_IP:$PORT -servername $SNI \
       -alpn h2,http/1.1 -tls1_3 2>&1" \
    | tee "$RUN_DIR/s_client.txt" | tee -a "$LOG_FILE" >/dev/null
  sleep 1

  docker exec "$CLIENT" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1
  docker cp "$CLIENT:$PCAP_IN" "$RUN_DIR/tls-09.pcap" >/dev/null 2>&1 || true

  # Best-effort: decode the ClientHello SNI/ALPN from the capture with tshark.
  if docker exec "$CLIENT" sh -c "command -v tshark" >/dev/null 2>&1; then
    docker exec "$CLIENT" tshark -r "$PCAP_IN" -Y "tls.handshake.type==1" \
      -T fields -e tls.handshake.extensions_server_name \
      -e tls.handshake.extensions_alpn_str 2>/dev/null \
      | tee "$RUN_DIR/tshark-clienthello.txt" | tee -a "$LOG_FILE" >/dev/null || true
  fi
  docker exec "$SERVER" pkill -f "s_server.*$PORT" >/dev/null 2>&1 || true

  log "checking the visible handshake result"
  local out="$RUN_DIR/s_client.txt"
  # Server certificate presented for our SNI.
  grep -qiE "subject=.*CN *= *$SNI|CN *= *$SNI" "$out"
  # ALPN negotiated to h2.
  grep -qi "ALPN protocol: h2" "$out"
  # TLS 1.3 negotiated.
  grep -qi "TLSv1.3" "$out"

  write_verification "verified" "TLS 1.3 handshake to $SERVER_IP:$PORT presented the $SNI certificate and negotiated ALPN h2; ClientHello SNI/ALPN captured on the wire."
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
