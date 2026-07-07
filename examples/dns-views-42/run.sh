#!/usr/bin/env bash
set -euo pipefail

LAB_ID="dns-views-42"
TOPOLOGY="dns-views-42.clab.yml"
BIND_IMAGE="protocol-lab/bind9:9.20"
INTERNAL_CLIENT="clab-dns-views-42-internal-client"
EXTERNAL_CLIENT="clab-dns-views-42-external-client"
INTERNAL_DNS="10.0.1.2"
EXTERNAL_DNS="203.0.113.2"
NAME="app.lab"
EXPECT_INTERNAL="10.0.0.5"
EXPECT_EXTERNAL="203.0.113.5"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/dns-views-42/runs/$RUN_ID}"
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
  log "deploying topology"
  sudo_cmd containerlab destroy -t "$TOPOLOGY" --cleanup >/dev/null 2>&1 || true
  run_cmd sudo_cmd containerlab deploy -t "$TOPOLOGY"
}

dig_a() { docker exec "$1" sh -c "dig +short $NAME @$2 | grep -E '^[0-9]' | head -1" 2>/dev/null; }

verify() {
  log "waiting for the server to answer $NAME"
  local i ready=0
  for i in $(seq 1 30); do
    if [ -n "$(dig_a "$INTERNAL_CLIENT" "$INTERNAL_DNS")" ]; then ready=1; log "server answering after ${i}s"; break; fi
    sleep 1
  done
  [ "$ready" = 1 ]

  log "internal-client (source in 10.0.1.0/24) resolves $NAME"
  local internal
  internal="$(dig_a "$INTERNAL_CLIENT" "$INTERNAL_DNS")"
  log "internal view: $NAME -> ${internal:-<none>} (expect $EXPECT_INTERNAL, the private address)"

  log "external-client (any other source) resolves the same $NAME"
  local external
  external="$(dig_a "$EXTERNAL_CLIENT" "$EXTERNAL_DNS")"
  log "external view: $NAME -> ${external:-<none>} (expect $EXPECT_EXTERNAL, the public address)"

  {
    echo "internal: ${internal:-NA}"
    echo "external: ${external:-NA}"
  } | tee "$RUN_DIR/result.txt" | tee -a "$LOG_FILE" >/dev/null

  log "checking the same name gave different answers per view"
  # Internal clients see the private address.
  [ "$internal" = "$EXPECT_INTERNAL" ]
  # External clients see the public address.
  [ "$external" = "$EXPECT_EXTERNAL" ]
  # And they genuinely differ.
  [ "$internal" != "$external" ]

  write_verification "verified" "Split-horizon DNS: the server is authoritative for $NAME through two views matched on the client source. The internal client (10.0.1.0/24) got $internal (the private address); the external client got $external (the public address) — the same name, a different answer depending on who asked."
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
  sudo_cmd /usr/sbin/ip netns list >/dev/null
}

action="${1:-run}"
case "$action" in
  deploy) build_image; deploy ;;
  verify) verify ;;
  destroy) destroy ;;
  doctor) doctor ;;
  run)
    trap destroy EXIT
    build_image
    deploy
    verify
    log "run complete: $RUN_DIR"
    ;;
  *)
    echo "Usage: $0 {run|deploy|verify|destroy|doctor}" >&2
    exit 1
    ;;
esac
