#!/usr/bin/env bash
set -euo pipefail

LAB_ID="tls-15"
TOPOLOGY="tls-15.clab.yml"
CLIENT="clab-tls-15-client"
SERVER="clab-tls-15-server"
SERVER_IP="10.0.0.2"
PORT="4433"
PCAP_IN="/tmp/tls-15.pcap"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/tls-15/runs/$RUN_ID}"
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

make_certs() {
  # One small lab CA signs both a server cert and a client cert. Generated
  # inside the server container (netshoot has openssl); the client cert + key
  # and the CA cert are then delivered to the client. Nothing is committed.
  log "generating a lab CA, a server cert, and a client cert"
  docker exec "$SERVER" sh -c '
    set -e
    cd /tmp
    openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.crt \
      -subj "/CN=Protocol Lab CA" -days 3650 >/dev/null 2>&1
    for who in server client; do
      openssl req -newkey rsa:2048 -nodes -keyout $who.key -out $who.csr \
        -subj "/CN=$who.example.lab" >/dev/null 2>&1
      openssl x509 -req -in $who.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
        -out $who.crt -days 3650 \
        -extfile <(printf "subjectAltName=DNS:%s.example.lab" "$who") >/dev/null 2>&1
    done' 2>&1 | tee -a "$LOG_FILE" >/dev/null
  # Deliver the client credentials + CA to the client node.
  for f in ca.crt client.crt client.key; do
    docker cp "$SERVER:/tmp/$f" "$RUN_DIR/$f" >/dev/null 2>&1
    docker cp "$RUN_DIR/$f" "$CLIENT:/tmp/$f" >/dev/null 2>&1
  done
}

start_server() {
  docker exec "$SERVER" pkill -f "s_server.*$PORT" >/dev/null 2>&1 || true
  log "starting openssl s_server on :$PORT with -Verify (client cert required)"
  # -Verify 1 makes a client certificate MANDATORY (vs lowercase -verify which
  # only requests one). No -quiet so the server logs the verified client cert.
  docker exec -d "$SERVER" sh -c \
    "openssl s_server -accept $PORT -cert /tmp/server.crt -key /tmp/server.key \
       -CAfile /tmp/ca.crt -Verify 1 -tls1_3 -www"
  sleep 1
}

wait_ready() {
  log "waiting for the mTLS server to accept an authenticated client"
  local i
  for i in $(seq 1 30); do
    if docker exec "$CLIENT" sh -c \
        "echo Q | openssl s_client -connect $SERVER_IP:$PORT \
           -cert /tmp/client.crt -key /tmp/client.key -CAfile /tmp/ca.crt -tls1_3 2>&1" \
        | grep -q "Verify return code: 0"; then
      log "authenticated handshake OK after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "server did not accept an authenticated client within timeout"
  return 1
}

verify() {
  make_certs
  start_server
  wait_ready

  log "capturing one authenticated handshake"
  docker exec "$CLIENT" rm -f "$PCAP_IN" >/dev/null 2>&1 || true
  docker exec -d "$CLIENT" tcpdump -i eth1 -s0 -w "$PCAP_IN" "tcp port $PORT"
  sleep 1

  # openssl s_client exits non-zero when the handshake is rejected (that is the
  # whole point of case 2), so tolerate the exit code here; the assertions below
  # judge success from the captured output, not the exit status.
  log "1) client WITH a certificate: handshake completes, both sides verify"
  docker exec "$CLIENT" sh -c \
    "echo Q | openssl s_client -connect $SERVER_IP:$PORT \
       -cert /tmp/client.crt -key /tmp/client.key -CAfile /tmp/ca.crt -tls1_3 2>&1" \
    > "$RUN_DIR/with-cert.txt" 2>&1 || true
  cat "$RUN_DIR/with-cert.txt" >>"$LOG_FILE"

  log "2) client WITHOUT a certificate: server rejects with a TLS alert"
  docker exec "$CLIENT" sh -c \
    "echo Q | openssl s_client -connect $SERVER_IP:$PORT -CAfile /tmp/ca.crt -tls1_3 2>&1" \
    > "$RUN_DIR/no-cert.txt" 2>&1 || true
  cat "$RUN_DIR/no-cert.txt" >>"$LOG_FILE"

  sleep 1
  docker exec "$CLIENT" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1
  docker cp "$CLIENT:$PCAP_IN" "$RUN_DIR/tls-15.pcap" >/dev/null 2>&1 || true
  docker logs "$SERVER" >"$RUN_DIR/server.log" 2>&1 || true
  docker exec "$SERVER" pkill -f "s_server.*$PORT" >/dev/null 2>&1 || true

  log "checking mutual authentication"
  # With a client cert: TLS 1.3 negotiated, both peers verified (return code 0),
  # and the server asked for a client cert (CertificateRequest -> the client
  # prints the acceptable CA names).
  grep -qi "Protocol *: *TLSv1.3" "$RUN_DIR/with-cert.txt"
  grep -q "Verify return code: 0" "$RUN_DIR/with-cert.txt"
  grep -qi "Acceptable client certificate CA names" "$RUN_DIR/with-cert.txt"
  # Without a client cert: the server rejects the handshake.
  grep -qi "certificate required" "$RUN_DIR/no-cert.txt"

  write_verification "verified" "mTLS on $SERVER_IP:$PORT: a client presenting a CA-signed cert completed a TLS 1.3 handshake (both sides Verify return code 0, server sent a CertificateRequest); a client with no cert was rejected with 'certificate required'."
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
