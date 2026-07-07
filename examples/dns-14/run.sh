#!/usr/bin/env bash
set -euo pipefail

LAB_ID="dns-14"
TOPOLOGY="dns-14.clab.yml"
CLIENT="clab-dns-14-client"
SERVER="clab-dns-14-server"
SERVER_IP="10.0.0.2"
QNAME="www.example.lab"
GOOD_A="203.0.113.10"
# A distinctive name used only to test what leaks onto the wire.
PROBE="leak-probe.example.lab"
TOKEN="leak-probe"
BIND_IMAGE="protocol-lab/bind9:9.20"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/dns-14/runs/$RUN_ID}"
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
  log "building $BIND_IMAGE"
  run_cmd docker build -t "$BIND_IMAGE" "$LAB_DIR"
}

make_cert() {
  # Self-signed cert for the DoT/DoH listener. Generated fresh (netshoot has
  # openssl; the BIND image does not) into a gitignored dir bind-mounted below,
  # so no private key is ever committed.
  log "generating a self-signed TLS cert for dns.example.lab"
  rm -rf "$LAB_DIR/server/tls"
  mkdir -p "$LAB_DIR/server/tls"
  docker run --rm -v "$LAB_DIR/server/tls:/w" -w /w --entrypoint sh nicolaka/netshoot:latest -c \
    'openssl req -x509 -newkey rsa:2048 -nodes -keyout server.key -out server.crt \
       -subj "/CN=dns.example.lab" -days 3650 \
       -addext "subjectAltName=DNS:dns.example.lab" >/dev/null 2>&1; \
     chmod 644 server.key server.crt'
}

deploy() {
  build_image
  make_cert
  log "deploying topology"
  sudo_cmd containerlab destroy -t "$TOPOLOGY" --cleanup >/dev/null 2>&1 || true
  run_cmd sudo_cmd containerlab deploy -t "$TOPOLOGY"
}

wait_ready() {
  log "waiting for the server to answer $QNAME over Do53"
  local i
  for i in $(seq 1 45); do
    if docker exec "$CLIENT" dig +short "@$SERVER_IP" "$QNAME" A 2>/dev/null | grep -q "$GOOD_A"; then
      log "server answered after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "server did not answer within timeout"
  return 1
}

# Capture one query of $PROBE over the given transport, then report whether the
# query name appears in cleartext. $1=label $2=port $3=extra dig flags
probe_transport() {
  local label="$1" port="$2" flags="$3"
  local pcap="/tmp/dns-14-$label.pcap"
  docker exec "$CLIENT" rm -f "$pcap" >/dev/null 2>&1 || true
  docker exec -d "$CLIENT" tcpdump -i eth1 -A -s0 -w "$pcap" "tcp port $port or udp port $port"
  sleep 1
  docker exec "$CLIENT" sh -c "dig $flags @$SERVER_IP $PROBE A >/dev/null 2>&1" || true
  sleep 1
  docker exec "$CLIENT" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1
  docker cp "$CLIENT:$pcap" "$RUN_DIR/$label.pcap" >/dev/null 2>&1 || true
  # Cleartext view of the capture.
  docker exec "$CLIENT" tcpdump -A -r "$pcap" 2>/dev/null \
    | tee "$RUN_DIR/$label.txt" >/dev/null || true
  # TLS handshake view: the message types seen (1=ClientHello, 2=ServerHello,
  # 11=Certificate). Empty for Do53 (no TLS). Needs tshark (netshoot ships it).
  docker exec "$CLIENT" sh -c \
    "tshark -r $pcap -Y 'tls.handshake' -T fields -e tls.handshake.type 2>/dev/null | tr '\n' ' '" \
    | tee "$RUN_DIR/$label-tls.txt" >/dev/null || true
}

verify() {
  wait_ready

  log "1) Do53 (plaintext), DoT (+tls), DoH (+https) all return the same answer"
  {
    echo "# Do53";   docker exec "$CLIENT" dig +short "@$SERVER_IP" "$QNAME" A
    echo "# DoT";    docker exec "$CLIENT" dig +tls +short "@$SERVER_IP" "$QNAME" A
    echo "# DoH";    docker exec "$CLIENT" dig +https +short "@$SERVER_IP" "$QNAME" A
  } | tee "$RUN_DIR/answers.txt" | tee -a "$LOG_FILE" >/dev/null

  log "2) capturing each transport while querying $PROBE"
  probe_transport "do53" 53 ""
  probe_transport "dot" 853 "+tls"
  probe_transport "doh" 443 "+https"

  log "checking what is visible on the wire"
  # All three transports resolved the name.
  [ "$(grep -c "$GOOD_A" "$RUN_DIR/answers.txt")" -eq 3 ]
  # Do53: the query name is in cleartext.
  grep -q "$TOKEN" "$RUN_DIR/do53.txt"
  # DoT / DoH: the query name is NOT in cleartext (it is inside TLS).
  ! grep -q "$TOKEN" "$RUN_DIR/dot.txt"
  ! grep -q "$TOKEN" "$RUN_DIR/doh.txt"
  # DoT / DoH carried a TLS ClientHello (type 1); Do53 carried no TLS at all.
  grep -qw 1 "$RUN_DIR/dot-tls.txt"
  grep -qw 1 "$RUN_DIR/doh-tls.txt"
  [ ! -s "$RUN_DIR/do53-tls.txt" ]

  write_verification "verified" "example.lab resolved to $GOOD_A over Do53, DoT, and DoH; the query name '$PROBE' was cleartext on port 53 but hidden inside TLS on 853 (DoT) and 443 (DoH)."
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
  command -v dig
  command -v tshark || true
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
