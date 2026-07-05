#!/usr/bin/env bash
set -euo pipefail

LAB_ID="quic-11"
TOPOLOGY="quic-11.clab.yml"
CLIENT="clab-quic-11-client"
SERVER="clab-quic-11-server"
SERVER_IP="10.0.0.2"
# Caddy's internal CA issues a leaf cert for the named site (www.example.lab),
# so the client connects by name (via --resolve) to send a matching SNI.
SNI_HOST="www.example.lab"
BASE="https://$SNI_HOST"
RESOLVE="--resolve $SNI_HOST:443:$SERVER_IP"
CADDY_IMAGE="protocol-lab/caddy:2"
PCAP_IN="/tmp/quic-11.pcap"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/quic-11/runs/$RUN_ID}"
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
  log "building $CADDY_IMAGE (Caddy + iproute2)"
  run_cmd docker build -t "$CADDY_IMAGE" "$LAB_DIR"
}

deploy() {
  build_image
  log "deploying topology"
  sudo_cmd containerlab destroy -t "$TOPOLOGY" --cleanup >/dev/null 2>&1 || true
  run_cmd sudo_cmd containerlab deploy -t "$TOPOLOGY"
}

wait_https() {
  log "waiting for the Caddy server on $BASE"
  local i
  for i in $(seq 1 40); do
    if docker exec "$CLIENT" curl -k $RESOLVE -s -o /dev/null "$BASE/" 2>/dev/null; then
      log "server answered after ${i}s"; return 0
    fi
    sleep 1
  done
  log "server did not answer within timeout"; return 1
}

verify() {
  wait_https

  log "client curl capabilities"
  docker exec "$CLIENT" curl -V | tee "$RUN_DIR/curl-version.txt" | tee -a "$LOG_FILE" >/dev/null

  log "single HTTP/2 fetch (ALPN h2 over TLS)"
  docker exec "$CLIENT" sh -c "curl -k $RESOLVE --http2 -sv $BASE/one 2>&1" \
    | tee "$RUN_DIR/h2-single.txt" | tee -a "$LOG_FILE" >/dev/null

  log "multiplexed HTTP/2 fetch: 3 requests over one connection"
  docker exec "$CLIENT" rm -f "$PCAP_IN" >/dev/null 2>&1 || true
  docker exec -d "$CLIENT" tcpdump -i eth1 -U -w "$PCAP_IN" "tcp port 443 or udp port 443"
  sleep 1
  docker exec "$CLIENT" sh -c \
    "curl -k $RESOLVE --http2 -sv --parallel \
       $BASE/a $BASE/b $BASE/c 2>&1" \
    | tee "$RUN_DIR/h2-multiplex.txt" | tee -a "$LOG_FILE" >/dev/null
  # Stop the capture right after the multiplexed fetch so the connection count
  # reflects only those 3 requests (later fetches would open their own conns).
  sleep 1
  docker exec "$CLIENT" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1
  docker cp "$CLIENT:$PCAP_IN" "$RUN_DIR/quic-11.pcap" >/dev/null 2>&1 || true

  # How many distinct TCP connections carried the 3 multiplexed requests?
  local conns
  conns="$(docker exec "$CLIENT" tcpdump -n -r "$PCAP_IN" "tcp[tcpflags] & tcp-syn != 0 and tcp[tcpflags] & tcp-ack == 0" 2>/dev/null | wc -l | tr -d ' ')"
  log "distinct TCP connections opened during the multiplexed fetch: $conns (1 = fully multiplexed)"

  log "response headers (look for Alt-Svc advertising h3)"
  docker exec "$CLIENT" sh -c "curl -k $RESOLVE --http2 -sD - -o /dev/null $BASE/ 2>&1" \
    | tee "$RUN_DIR/headers.txt" | tee -a "$LOG_FILE" >/dev/null

  # Best-effort HTTP/3 if this curl was built with HTTP3 support.
  if docker exec "$CLIENT" sh -c "curl -V | grep -qi HTTP3"; then
    log "client curl supports HTTP/3; trying an HTTP/3 fetch"
    docker exec "$CLIENT" sh -c "curl -k $RESOLVE --http3 -sv $BASE/three 2>&1" \
      | tee "$RUN_DIR/h3-fetch.txt" | tee -a "$LOG_FILE" >/dev/null || true
  else
    log "client curl has no HTTP/3 support; showing the QUIC listener instead"
    docker exec "$SERVER" sh -c "ss -uln 2>/dev/null || netstat -uln 2>/dev/null" \
      | tee "$RUN_DIR/server-udp-listeners.txt" | tee -a "$LOG_FILE" >/dev/null || true
  fi

  log "checking HTTP/2 negotiation and h3 advertisement"
  # HTTP/2 was negotiated (curl says so, and the body echoes the protocol).
  grep -qiE "using HTTP/2|HTTP/2.0" "$RUN_DIR/h2-single.txt"
  # Server advertises HTTP/3 via Alt-Svc.
  grep -qiE "alt-svc:.*h3" "$RUN_DIR/headers.txt"

  write_verification "verified" "HTTP/2 negotiated over TLS and 3 requests multiplexed over ${conns} TCP connection(s); server advertises HTTP/3 via Alt-Svc (h3)."
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
