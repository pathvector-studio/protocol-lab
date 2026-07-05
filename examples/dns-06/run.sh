#!/usr/bin/env bash
set -euo pipefail

LAB_ID="dns-06"
TOPOLOGY="dns-06.clab.yml"
CLIENT="clab-dns-06-client"
RESOLVER="clab-dns-06-resolver"
BIND_IMAGE="protocol-lab/bind9:9.20"
QNAME="www.example.lab"
STABLE="stable.example.lab"
MISSING="missing.example.lab"
EXPECTED_A="203.0.113.10"
RESOLVER_IP="10.0.0.1"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/dns-06/runs/$RUN_ID}"
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

# Pull the TTL (field 2) out of a "+noall +answer" line.
answer_ttl() {
  docker exec "$CLIENT" dig +noall +answer "@$RESOLVER_IP" "$1" A 2>/dev/null \
    | awk 'NR==1 {print $2}'
}

build_image() {
  # The BIND nodes need iproute2 (for the exec IP setup) and a foreground
  # named; the upstream ISC image lacks both. Build the thin wrapper first.
  log "building $BIND_IMAGE"
  run_cmd docker build -t "$BIND_IMAGE" "$LAB_DIR"
}

deploy() {
  build_image
  log "deploying topology"
  sudo_cmd containerlab destroy -t "$TOPOLOGY" --cleanup >/dev/null 2>&1 || true
  run_cmd sudo_cmd containerlab deploy -t "$TOPOLOGY"
}

wait_resolution() {
  log "waiting for the resolver to answer $QNAME"
  local i
  for i in $(seq 1 45); do
    local output
    output="$(docker exec "$CLIENT" dig +short "@$RESOLVER_IP" "$QNAME" A 2>/dev/null || true)"
    if grep -q "$EXPECTED_A" <<<"$output"; then
      log "resolver answered after ${i}s"
      return 0
    fi
    sleep 1
  done
  log "resolver did not answer within timeout"
  return 1
}

verify() {
  wait_resolution

  log "observing TTL countdown for $QNAME"
  # First query fills the cache at TTL 60; wait, then re-query to see it drop.
  local ttl1 ttl2
  docker exec "$CLIENT" dig "@$RESOLVER_IP" "$QNAME" A \
    | tee "$RUN_DIR/dig-ttl-first-$QNAME.txt" | tee -a "$LOG_FILE" >/dev/null
  ttl1="$(answer_ttl "$QNAME")"
  sleep 3
  docker exec "$CLIENT" dig "@$RESOLVER_IP" "$QNAME" A \
    | tee "$RUN_DIR/dig-ttl-second-$QNAME.txt" | tee -a "$LOG_FILE" >/dev/null
  ttl2="$(answer_ttl "$QNAME")"
  log "TTL for $QNAME: first=$ttl1 second=$ttl2 (expect second < first while cached)"

  log "querying a long-TTL name for contrast: $STABLE"
  docker exec "$CLIENT" dig "@$RESOLVER_IP" "$STABLE" A \
    | tee "$RUN_DIR/dig-$STABLE.txt" | tee -a "$LOG_FILE" >/dev/null

  log "querying a missing name for a negative answer: $MISSING"
  docker exec "$CLIENT" dig "@$RESOLVER_IP" "$MISSING" A \
    | tee "$RUN_DIR/dig-nxdomain-$MISSING.txt" | tee -a "$LOG_FILE" >/dev/null
  # Second identical query should be served from the negative cache.
  docker exec "$CLIENT" dig "@$RESOLVER_IP" "$MISSING" A \
    | tee "$RUN_DIR/dig-nxdomain-second-$MISSING.txt" | tee -a "$LOG_FILE" >/dev/null

  docker logs "$RESOLVER" >"$RUN_DIR/resolver.log" 2>&1 || true

  log "checking expected observations"
  # Positive answer present.
  grep -q "$EXPECTED_A" "$RUN_DIR/dig-ttl-first-$QNAME.txt"
  # TTL counted down while cached (numeric compare; both must be integers).
  if [[ "$ttl1" =~ ^[0-9]+$ && "$ttl2" =~ ^[0-9]+$ ]]; then
    [ "$ttl2" -lt "$ttl1" ]
  else
    log "WARN: could not parse TTLs (ttl1=$ttl1 ttl2=$ttl2)"
    false
  fi
  # Negative answer is an NXDOMAIN carrying the zone SOA.
  grep -q "status: NXDOMAIN" "$RUN_DIR/dig-nxdomain-$MISSING.txt"
  grep -qi "SOA" "$RUN_DIR/dig-nxdomain-$MISSING.txt"

  write_verification "verified" "www.example.lab TTL counted down from $ttl1 to $ttl2 while cached; missing.example.lab returned NXDOMAIN with the example.lab. SOA for negative caching."
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
