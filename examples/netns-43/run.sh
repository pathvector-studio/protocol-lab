#!/usr/bin/env bash
set -euo pipefail

# Lab 43 differs from the containerlab labs on purpose: the whole point is to
# build the wiring by hand, so there is no topology file. One privileged
# container plays the host, and build-topology.sh assembles everything inside
# it. That also means this lab needs no root on your machine.

LAB_ID="netns-43"
IMAGE="protocol-lab/netns-lab:alpine3.21"
CONTAINER="protocol-lab-netns-43"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/netns-43/runs/$RUN_ID}"
LOG_FILE="$RUN_DIR/run.log"
TOPOLOGY_LOG="$RUN_DIR/topology.log"

mkdir -p "$RUN_DIR"

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
  log "building $IMAGE"
  run_cmd docker build -t "$IMAGE" "$LAB_DIR"
}

deploy() {
  log "building the topology by hand inside a privileged container"
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  # --privileged is what lets the container create namespaces and a bridge of
  # its own. Nothing escapes to the host: every interface below lives in this
  # container's network namespace and dies with it.
  docker run --name "$CONTAINER" --privileged "$IMAGE" 2>&1 | tee "$TOPOLOGY_LOG" | tee -a "$LOG_FILE"
}

verify() {
  log "checking the build log"
  [ -s "$TOPOLOGY_LOG" ] || { log "no topology log at $TOPOLOGY_LOG"; return 1; }

  log "step 3: the ping before the bridge must fail"
  grep -q '(expected) unreachable' "$TOPOLOGY_LOG"

  log "step 5: the same ping after the bridge must succeed"
  grep -qE '3 packets transmitted, 3 (packets )?received' "$TOPOLOGY_LOG"

  log "step 6: the bridge must have learned both MACs"
  local learned
  learned="$(sed -n '/step 6/,/step 7/p' "$TOPOLOGY_LOG" | grep -cE '^[0-9a-f:]{17} dev veth-(red|blue)' || true)"
  log "learned FDB entries: $learned (expect 2)"
  [ "$learned" -eq 2 ]

  {
    echo "before bridge: unreachable"
    echo "after bridge: reachable"
    echo "fdb entries learned: $learned"
  } | tee "$RUN_DIR/result.txt" | tee -a "$LOG_FILE" >/dev/null

  write_verification "verified" "Container networking built from primitives: two network namespaces with veth pairs were configured on one subnet but could not reach each other, because the host-side ends were not connected to anything. Enslaving both ends to a Linux bridge made the same ping succeed, and the bridge learned $learned MAC addresses — one per port."
  log "verification OK"
}

destroy() {
  log "removing the lab container"
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}

doctor() {
  log "doctor"
  command -v docker
  command -v jq
  docker info --format 'docker {{.ServerVersion}}'
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
