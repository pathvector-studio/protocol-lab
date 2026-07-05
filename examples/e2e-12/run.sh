#!/usr/bin/env bash
set -euo pipefail

LAB_ID="e2e-12"
TOPOLOGY="e2e-12.clab.yml"
CLIENT="clab-e2e-12-client"
DNS="clab-e2e-12-dns"
WEB="clab-e2e-12-web"
DNS_IP="10.0.1.2"
WEB_IP="10.0.2.2"
NAME="www.example.lab"
BIND_IMAGE="protocol-lab/bind9:9.20"
CADDY_IMAGE="protocol-lab/caddy:2"
PCAP_DNS="/tmp/e2e-dns.pcap"
PCAP_WEB="/tmp/e2e-web.pcap"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/e2e-12/runs/$RUN_ID}"
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

build_images() {
  log "building $BIND_IMAGE and $CADDY_IMAGE"
  run_cmd docker build -t "$BIND_IMAGE" "$LAB_DIR/dns"
  run_cmd docker build -t "$CADDY_IMAGE" "$LAB_DIR/web"
}

deploy() {
  build_images
  log "deploying topology"
  sudo_cmd containerlab destroy -t "$TOPOLOGY" --cleanup >/dev/null 2>&1 || true
  run_cmd sudo_cmd containerlab deploy -t "$TOPOLOGY"
}

set_resolv() {
  log "pointing the client resolver at $DNS_IP"
  docker exec "$CLIENT" sh -c "printf 'nameserver %s\n' '$DNS_IP' > /etc/resolv.conf"
}

wait_ready() {
  log "waiting for DNS ($NAME) and the web server"
  local i
  for i in $(seq 1 45); do
    local a
    a="$(docker exec "$CLIENT" dig +short "@$DNS_IP" "$NAME" A 2>/dev/null || true)"
    if grep -q "$WEB_IP" <<<"$a" \
       && docker exec "$CLIENT" curl -k -s -o /dev/null "https://$WEB_IP/" 2>/dev/null; then
      log "DNS and web ready after ${i}s"; return 0
    fi
    sleep 1
  done
  log "stack did not become ready within timeout"; return 1
}

verify() {
  set_resolv
  wait_ready

  log "layer 1 (DNS): resolve $NAME"
  docker exec "$CLIENT" dig "@$DNS_IP" "$NAME" A \
    | tee "$RUN_DIR/dig.txt" | tee -a "$LOG_FILE" >/dev/null

  log "starting captures: eth1 (DNS) and eth2 (web)"
  docker exec "$CLIENT" rm -f "$PCAP_DNS" "$PCAP_WEB" >/dev/null 2>&1 || true
  docker exec -d "$CLIENT" tcpdump -i eth1 -U -w "$PCAP_DNS" "udp port 53"
  docker exec -d "$CLIENT" tcpdump -i eth2 -U -s0 -w "$PCAP_WEB" "tcp port 443"
  sleep 1

  log "layers 2-4 (TCP+TLS+HTTP): one request to https://$NAME/"
  # curl resolves via /etc/resolv.conf, then does TCP, TLS (SNI), and HTTP.
  docker exec "$CLIENT" sh -c "curl -k --http2 -sv https://$NAME/ 2>&1" \
    | tee "$RUN_DIR/curl.txt" | tee -a "$LOG_FILE" >/dev/null
  sleep 1

  docker exec "$CLIENT" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1
  docker cp "$CLIENT:$PCAP_DNS" "$RUN_DIR/e2e-dns.pcap" >/dev/null 2>&1 || true
  docker cp "$CLIENT:$PCAP_WEB" "$RUN_DIR/e2e-web.pcap" >/dev/null 2>&1 || true
  docker exec "$CLIENT" tcpdump -tttt -n -r "$PCAP_DNS" 2>/dev/null \
    | tee "$RUN_DIR/tcpdump-dns.txt" >/dev/null || true
  docker exec "$CLIENT" tcpdump -tttt -n -r "$PCAP_WEB" 2>/dev/null \
    | tee "$RUN_DIR/tcpdump-web.txt" >/dev/null || true

  log "checking each layer left its mark"
  # DNS resolved the name to the web server address.
  grep -qE "^$NAME\.[[:space:]]+.*[[:space:]]A[[:space:]]+$WEB_IP" "$RUN_DIR/dig.txt"
  # curl connected to the resolved address.
  grep -qE "Connected to $NAME \($WEB_IP\)|Trying $WEB_IP" "$RUN_DIR/curl.txt"
  # TLS handshake happened (ALPN / TLS lines) and HTTP succeeded.
  grep -qiE "SSL connection using TL|ALPN: server accepted|using HTTP/2" "$RUN_DIR/curl.txt"
  grep -qiE "HTTP/2 200|HTTP/1.1 200|< HTTP/2 200" "$RUN_DIR/curl.txt"
  # The web server's body came back.
  grep -qi "Hello from example.lab" "$RUN_DIR/curl.txt"

  write_verification "verified" "End-to-end: DNS resolved $NAME to $WEB_IP, then one TLS+HTTP/2 request to that address returned 200 with the example.lab body."
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
