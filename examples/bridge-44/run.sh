#!/usr/bin/env bash
set -euo pipefail

# Like Lab 43, this lab has no containerlab topology: everything is assembled
# inside one privileged container by observe-bridge.sh, so it needs no root on
# your machine. What the script measures is how many frames the third namespace
# receives before and after the bridge learns where the destination lives.

LAB_ID="bridge-44"
IMAGE="protocol-lab/bridge-lab:alpine3.21"
CONTAINER="protocol-lab-bridge-44"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/bridge-44/runs/$RUN_ID}"
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

  log "step 2: the FDB must start empty"
  grep -q 'no learned entries' "$TOPOLOGY_LOG"

  log "step 3: unknown unicast must reach the bystander (flooded)"
  local unknown learned again
  unknown="$(sed -n 's/^frames c received that were addressed to b: \([0-9]*\) (expect 1.*/\1/p' "$TOPOLOGY_LOG" | head -1)"
  log "frames seen while b was unknown: ${unknown:-none} (expect >= 1)"
  [ -n "$unknown" ] && [ "$unknown" -ge 1 ]

  log "step 5: the same traffic must not reach the bystander once learned"
  learned="$(sed -n 's/^frames c received that were addressed to b: \([0-9]*\) (expect 0.*/\1/p' "$TOPOLOGY_LOG" | head -1)"
  log "frames seen after learning: ${learned:-none} (expect 0)"
  [ -n "$learned" ] && [ "$learned" -eq 0 ]

  log "step 6: deleting the entry must bring the flooding back"
  again="$(sed -n 's/^frames c received after deleting b.s entry: \([0-9]*\).*/\1/p' "$TOPOLOGY_LOG" | head -1)"
  log "frames seen after deleting b: ${again:-none} (expect >= 1)"
  [ -n "$again" ] && [ "$again" -ge 1 ]

  log "step 7: entries must age out on their own"
  grep -q 'all learned entries aged out' "$TOPOLOGY_LOG"

  {
    echo "unknown unicast -> bystander saw: $unknown"
    echo "learned         -> bystander saw: $learned"
    echo "entry deleted   -> bystander saw: $again"
    echo "ageing: learned entries expired with no traffic"
  } | tee "$RUN_DIR/result.txt" | tee -a "$LOG_FILE" >/dev/null

  write_verification "verified" "Bridge learning observed end to end: with b's address unknown the bridge flooded the frame and the bystander c received $unknown copy; once the bridge had learned b from the reply's source address, the identical traffic reached c $learned times; deleting only that FDB entry brought the flooding back ($again); and with a short ageing_time the learned entries expired on their own."
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
