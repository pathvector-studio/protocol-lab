#!/usr/bin/env bash
set -euo pipefail

LAB_ID="dns-05"
TOPOLOGY="dns-05.clab.yml"
CLIENT="clab-dns-05-client"
RESOLVER="clab-dns-05-resolver"
BIND_IMAGE="protocol-lab/bind9:9.20"
QNAME="www.example.lab"
EXPECTED_A="203.0.113.10"
RESOLVER_IP="10.0.0.1"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/dns-05/runs/$RUN_ID}"
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

  log "collecting dig output from the client"
  # Iterative path: dig +trace follows referrals root -> lab. -> example.lab.
  docker exec "$CLIENT" dig +trace "@$RESOLVER_IP" "$QNAME" A \
    | tee "$RUN_DIR/dig-trace-$QNAME.txt" | tee -a "$LOG_FILE" >/dev/null

  # First recursive query: full iteration, non-zero query time.
  docker exec "$CLIENT" dig "@$RESOLVER_IP" "$QNAME" A \
    | tee "$RUN_DIR/dig-first-$QNAME.txt" | tee -a "$LOG_FILE" >/dev/null

  # Second recursive query: served from the resolver cache.
  docker exec "$CLIENT" dig "@$RESOLVER_IP" "$QNAME" A \
    | tee "$RUN_DIR/dig-second-$QNAME.txt" | tee -a "$LOG_FILE" >/dev/null

  # Cache probe: recursion desired off still returns the cached answer.
  docker exec "$CLIENT" dig +norecurse "@$RESOLVER_IP" "$QNAME" A \
    | tee "$RUN_DIR/dig-norecurse-$QNAME.txt" | tee -a "$LOG_FILE" >/dev/null

  # Resolver's view of the client request.
  docker logs "$RESOLVER" >"$RUN_DIR/resolver.log" 2>&1 || true

  log "checking expected observations"
  # Final answer is present.
  grep -q "$EXPECTED_A" "$RUN_DIR/dig-first-$QNAME.txt"
  # +trace visited each level of the hierarchy.
  grep -qE "^lab\.[[:space:]]" "$RUN_DIR/dig-trace-$QNAME.txt"
  grep -qE "example\.lab\.[[:space:]]" "$RUN_DIR/dig-trace-$QNAME.txt"
  grep -q "$EXPECTED_A" "$RUN_DIR/dig-trace-$QNAME.txt"
  # The cache probe (no recursion) still answered.
  grep -q "$EXPECTED_A" "$RUN_DIR/dig-norecurse-$QNAME.txt"

  write_verification "verified" "Recursive resolution of $QNAME returned $EXPECTED_A; dig +trace shows referrals root -> lab. -> example.lab.; the cached answer is served without recursion."
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
