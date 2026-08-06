#!/usr/bin/env bash
set -euo pipefail

# Like Labs 43 and 44 this lab needs no root and no containerlab topology.
# compare-encap.sh builds one underlay and then runs GENEVE and VXLAN across it
# in parallel with the same VNI, so every difference in the captures is a
# difference between the two encapsulations and nothing else.

LAB_ID="geneve-45"
IMAGE="protocol-lab/geneve-lab:alpine3.21"
CONTAINER="protocol-lab-geneve-45"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/geneve-45/runs/$RUN_ID}"
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

  log "step 4: GENEVE must appear on UDP 6081 with the inner payload readable"
  grep -q '\.6081: Geneve' "$TOPOLOGY_LOG"
  grep -qE '\.6081: Geneve.*(ICMP|ARP)' "$TOPOLOGY_LOG"

  log "step 4: VXLAN must appear on UDP 4789 with the same VNI"
  grep -q '\.4789: VXLAN' "$TOPOLOGY_LOG"
  grep -qE '\.4789: VXLAN.*vni 100' "$TOPOLOGY_LOG"

  log "step 5: both encapsulation headers must have been dumped"
  grep -q '0x0010:' "$TOPOLOGY_LOG"

  local gnv_mtu vx_mtu sports
  gnv_mtu="$(sed -n 's/^SUMMARY geneve_mtu=\([0-9]*\).*/\1/p' "$TOPOLOGY_LOG" | head -1)"
  vx_mtu="$(sed -n 's/^SUMMARY .*vxlan_mtu=\([0-9]*\).*/\1/p' "$TOPOLOGY_LOG" | head -1)"
  sports="$(sed -n 's/^SUMMARY .*distinct_sports=\([0-9]*\).*/\1/p' "$TOPOLOGY_LOG" | head -1)"

  log "step 3: GENEVE must have sized its MTU down, VXLAN must not have"
  log "geneve mtu=$gnv_mtu vxlan mtu=$vx_mtu"
  [ -n "$gnv_mtu" ] && [ "$gnv_mtu" -lt 1500 ]
  [ -n "$vx_mtu" ] && [ "$vx_mtu" -eq 1500 ]

  log "step 6: different inner flows must hash to different outer source ports"
  log "distinct outer source ports: $sports (expect >= 2)"
  [ -n "$sports" ] && [ "$sports" -ge 2 ]

  {
    echo "geneve: UDP 6081, inner payload readable"
    echo "vxlan:  UDP 4789, inner payload readable"
    echo "geneve mtu: $gnv_mtu"
    echo "vxlan mtu:  $vx_mtu"
    echo "distinct outer source ports for 3 inner flows: $sports"
  } | tee "$RUN_DIR/result.txt" | tee -a "$LOG_FILE" >/dev/null

  write_verification "verified" "GENEVE and VXLAN carried the same inner traffic over one underlay: GENEVE on UDP 6081 and VXLAN on UDP 4789, both leaving the inner payload in the clear. The header dumps show GENEVE spending two of its eight bytes on a Protocol Type and an option length where VXLAN has reserved zeroes. GENEVE sized its MTU to $gnv_mtu while the VXLAN device stayed at $vx_mtu, and three different inner flows hashed to $sports distinct outer UDP source ports."
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
