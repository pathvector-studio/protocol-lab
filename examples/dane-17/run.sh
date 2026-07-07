#!/usr/bin/env bash
set -euo pipefail

LAB_ID="dane-17"
TOPOLOGY="dane-17.clab.yml"
CLIENT="clab-dane-17-client"
AUTH="clab-dane-17-auth"
WEB="clab-dane-17-web"
AUTH_IP="10.0.1.2"
WEB_IP="10.0.2.2"
NAME="www.example.lab"
TLSA_OWNER="_443._tcp.www.example.lab"
BIND_IMAGE="protocol-lab/bind9:9.20"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/dane-17/runs/$RUN_ID}"
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

deploy() {
  build_image
  log "deploying topology"
  sudo_cmd containerlab destroy -t "$TOPOLOGY" --cleanup >/dev/null 2>&1 || true
  run_cmd sudo_cmd containerlab deploy -t "$TOPOLOGY"
}

setup_web() {
  # A real cert for the web server (self-signed: DANE needs no CA) plus an
  # impostor cert with a different key. The TLSA record will pin the real one.
  log "generating the web server's real cert and an impostor cert"
  docker exec "$WEB" sh -c "
    openssl req -x509 -newkey rsa:2048 -nodes -keyout /tmp/real.key -out /tmp/real.crt \
      -subj '/CN=$NAME' -addext 'subjectAltName=DNS:$NAME' -days 3650 >/dev/null 2>&1
    openssl req -x509 -newkey rsa:2048 -nodes -keyout /tmp/imp.key -out /tmp/imp.crt \
      -subj '/CN=$NAME' -addext 'subjectAltName=DNS:$NAME' -days 3650 >/dev/null 2>&1"
  # TLSA "3 1 1" = DANE-EE / SubjectPublicKeyInfo / SHA-256 of the real cert.
  TLSA_HASH="$(docker exec "$WEB" sh -c \
    "openssl x509 -in /tmp/real.crt -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | openssl dgst -sha256 | awk '{print \$NF}'")"
  log "TLSA for $TLSA_OWNER = 3 1 1 $TLSA_HASH"
  # real cert on :443, impostor cert on :8443
  docker exec "$WEB" pkill -f "s_server" >/dev/null 2>&1 || true
  docker exec -d "$WEB" sh -c "openssl s_server -accept 443  -cert /tmp/real.crt -key /tmp/real.key -www -quiet"
  docker exec -d "$WEB" sh -c "openssl s_server -accept 8443 -cert /tmp/imp.crt  -key /tmp/imp.key  -www -quiet"
  sleep 1
}

sign_zone() {
  # Build example.lab with the TLSA that matches the real cert, then DNSSEC-sign
  # it (ECDSAP256SHA256) inside the auth container and load it.
  log "building and DNSSEC-signing example.lab (with the TLSA record)"
  cat >"$RUN_DIR/db.example.lab" <<EOF
\$TTL 300
example.lab.          IN SOA ns.example.lab. admin.example.lab. ( 1 3600 900 604800 300 )
example.lab.          IN NS  ns.example.lab.
ns.example.lab.       IN A   $AUTH_IP
$NAME.                IN A   $WEB_IP
$TLSA_OWNER. IN TLSA 3 1 1 $TLSA_HASH
EOF
  docker cp "$RUN_DIR/db.example.lab" "$AUTH:/var/cache/bind/db.example.lab" >/dev/null
  docker exec "$AUTH" sh -c '
    cd /var/cache/bind
    dnssec-keygen -a ECDSAP256SHA256 -f KSK -n ZONE -K . example.lab >/dev/null 2>&1
    dnssec-keygen -a ECDSAP256SHA256 -n ZONE -K . example.lab >/dev/null 2>&1
    dnssec-signzone -S -K . -o example.lab -e +315360000 -x -t db.example.lab >/dev/null 2>&1
    chown bind db.example.lab.signed
    kill -HUP $(pidof named) 2>/dev/null || kill -HUP 1' 2>&1 | tee -a "$LOG_FILE" >/dev/null
  sleep 1
}

wait_ready() {
  log "waiting for auth to serve the signed zone and web to answer TLS"
  local i
  for i in $(seq 1 45); do
    if docker exec "$CLIENT" dig +short "@$AUTH_IP" "$NAME" A 2>/dev/null | grep -q "$WEB_IP" \
       && docker exec "$CLIENT" sh -c "echo | openssl s_client -connect $WEB_IP:443 2>/dev/null" | grep -q "CN"; then
      log "stack ready after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "stack did not become ready within timeout"
  return 1
}

verify() {
  setup_web
  sign_zone
  wait_ready

  log "1) fetch the TLSA record from DNS (signed: it carries an RRSIG)"
  docker exec "$CLIENT" dig +dnssec "@$AUTH_IP" "$TLSA_OWNER" TLSA \
    | tee "$RUN_DIR/dig-tlsa.txt" | tee -a "$LOG_FILE" >/dev/null
  # The TLSA rdata the client will validate against.
  local rrdata
  rrdata="$(docker exec "$CLIENT" dig +short "@$AUTH_IP" "$TLSA_OWNER" TLSA | head -1)"
  log "TLSA rrdata from DNS: $rrdata"

  log "2) validate the real web cert against the TLSA (DANE, no CA)"
  docker exec "$CLIENT" sh -c \
    "echo Q | openssl s_client -connect $WEB_IP:443 \
       -dane_tlsa_domain $NAME -dane_tlsa_rrdata '$rrdata' 2>&1" \
    > "$RUN_DIR/dane-real.txt" 2>&1 || true
  cat "$RUN_DIR/dane-real.txt" >>"$LOG_FILE"

  log "3) validate an impostor cert (different key) against the same TLSA -> rejected"
  docker exec "$CLIENT" sh -c \
    "echo Q | openssl s_client -connect $WEB_IP:8443 \
       -dane_tlsa_domain $NAME -dane_tlsa_rrdata '$rrdata' 2>&1" \
    > "$RUN_DIR/dane-impostor.txt" 2>&1 || true
  cat "$RUN_DIR/dane-impostor.txt" >>"$LOG_FILE"

  log "checking DANE validation"
  # The TLSA is published and DNSSEC-signed.
  grep -qiE "IN[[:space:]]+TLSA[[:space:]]+3 1 1|TLSA.*3 1 1" "$RUN_DIR/dig-tlsa.txt"
  grep -qi "RRSIG" "$RUN_DIR/dig-tlsa.txt"
  # The real cert matches the TLSA (self-signed, yet DANE-valid).
  grep -qi "matched the EE certificate" "$RUN_DIR/dane-real.txt"
  grep -q "Verify return code: 0" "$RUN_DIR/dane-real.txt"
  # The impostor cert does not match -> rejected.
  grep -qi "no matching DANE TLSA records" "$RUN_DIR/dane-impostor.txt"

  write_verification "verified" "DANE: a DNSSEC-signed TLSA ($rrdata) pinned the web cert. The real self-signed cert matched (Verify return code 0, no CA needed); an impostor cert with a different key was rejected (no matching DANE TLSA records)."
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
