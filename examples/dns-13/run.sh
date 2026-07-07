#!/usr/bin/env bash
set -euo pipefail

LAB_ID="dns-13"
TOPOLOGY="dns-13.clab.yml"
CLIENT="clab-dns-13-client"
RESOLVER="clab-dns-13-resolver"
AUTH="clab-dns-13-auth"
RESOLVER_IP="10.0.0.1"
AUTH_IP="10.0.1.2"
QNAME="www.example.lab"
GOOD_A="203.0.113.10"
BOGUS_A="203.0.113.66"
BIND_IMAGE="protocol-lab/bind9:9.20"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/dns-13/runs/$RUN_ID}"
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

# named runs as PID 1 (CMD), but target it by name to be safe.
reload_auth() {
  docker exec "$AUTH" sh -c 'kill -HUP $(pidof named) 2>/dev/null || kill -HUP 1'
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

load_zone() {
  # The signed zone is bind-mounted read-only at /etc/bind. Copy it into the
  # writable working dir named actually serves from, then (re)load it. This
  # keeps the repo file pristine so the tamper step below has something to edit.
  log "delivering the signed example.lab zone to auth and loading it"
  docker exec "$AUTH" sh -c \
    'cp /etc/bind/db.example.lab.signed /var/cache/bind/db.example.lab.signed \
       && chown bind /var/cache/bind/db.example.lab.signed'
  reload_auth
  sleep 1
}

wait_ready() {
  log "waiting for the resolver to return a validated answer for $QNAME"
  local i out
  for i in $(seq 1 45); do
    out="$(docker exec "$CLIENT" dig +dnssec "@$RESOLVER_IP" "$QNAME" A 2>/dev/null || true)"
    if grep -q "$GOOD_A" <<<"$out" && grep -qE 'flags:[^;]* ad' <<<"$out"; then
      log "validated (AD) answer after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "resolver did not return a validated answer within timeout"
  return 1
}

tamper() {
  log "tampering the served zone: $QNAME A $GOOD_A -> $BOGUS_A (RRSIG no longer matches)"
  docker exec "$AUTH" sh -c \
    "sed 's/$GOOD_A/$BOGUS_A/' /var/cache/bind/db.example.lab.signed > /var/cache/bind/db.tmp \
       && mv /var/cache/bind/db.tmp /var/cache/bind/db.example.lab.signed \
       && chown bind /var/cache/bind/db.example.lab.signed"
  reload_auth
  sleep 1
  log "flushing the resolver cache so it re-queries the tampered zone"
  docker exec "$RESOLVER" rndc flush
  sleep 1
}

verify() {
  load_zone
  wait_ready

  log "1) valid query: dig +dnssec should carry the AD (Authenticated Data) flag"
  docker exec "$CLIENT" dig +dnssec "@$RESOLVER_IP" "$QNAME" A \
    | tee "$RUN_DIR/dig-valid.txt" | tee -a "$LOG_FILE" >/dev/null

  log "2) the signed zone's public keys (KSK 257 / ZSK 256)"
  docker exec "$CLIENT" dig +dnssec "@$RESOLVER_IP" example.lab DNSKEY \
    | tee "$RUN_DIR/dig-dnskey.txt" | tee -a "$LOG_FILE" >/dev/null

  tamper

  log "3) tampered query: validation must fail with SERVFAIL"
  docker exec "$CLIENT" dig +dnssec "@$RESOLVER_IP" "$QNAME" A \
    | tee "$RUN_DIR/dig-bogus.txt" | tee -a "$LOG_FILE" >/dev/null

  log "4) same query with +cd (checking disabled) bypasses validation and shows the tampered data"
  docker exec "$CLIENT" dig +cd "@$RESOLVER_IP" "$QNAME" A \
    | tee "$RUN_DIR/dig-cd.txt" | tee -a "$LOG_FILE" >/dev/null

  docker logs "$RESOLVER" >"$RUN_DIR/resolver.log" 2>&1 || true

  log "checking expected observations"
  # Valid answer is authenticated: NOERROR, AD flag, RRSIG present, right address.
  grep -q "status: NOERROR" "$RUN_DIR/dig-valid.txt"
  grep -qE "flags:[^;]* ad" "$RUN_DIR/dig-valid.txt"
  grep -q "RRSIG" "$RUN_DIR/dig-valid.txt"
  grep -q "$GOOD_A" "$RUN_DIR/dig-valid.txt"
  # The zone publishes a KSK (257) and a ZSK (256).
  grep -qE "DNSKEY[[:space:]]+257" "$RUN_DIR/dig-dnskey.txt"
  grep -qE "DNSKEY[[:space:]]+256" "$RUN_DIR/dig-dnskey.txt"
  # Tampered answer is rejected.
  grep -q "status: SERVFAIL" "$RUN_DIR/dig-bogus.txt"
  grep -qi "no valid signature" "$RUN_DIR/resolver.log"
  # With validation disabled (+cd) the tampered data is visible.
  grep -q "$BOGUS_A" "$RUN_DIR/dig-cd.txt"

  write_verification "verified" "Signed example.lab validated with the AD flag (KSK 257 + ZSK 256 present); a tampered $QNAME answer was rejected with SERVFAIL (no valid signature), while +cd exposed the unvalidated $BOGUS_A."
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
