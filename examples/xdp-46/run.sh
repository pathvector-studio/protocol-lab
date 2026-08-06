#!/usr/bin/env bash
set -euo pipefail

# Like Labs 43 and 44 this lab needs no root and no containerlab topology.
# observe-xdp.sh builds one underlay and then runs GENEVE and VXLAN across it
# in parallel with the same VNI, so every difference in the captures is a
# difference between the two encapsulations and nothing else.

LAB_ID="xdp-46"
IMAGE="protocol-lab/xdp-lab:alpine3.21"
CONTAINER="protocol-lab-xdp-46"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/xdp-46/runs/$RUN_ID}"
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
  docker run --name "$CONTAINER" --privileged --ulimit memlock=-1 "$IMAGE" 2>&1 | tee "$TOPOLOGY_LOG" | tee -a "$LOG_FILE"
}

verify() {
  log "checking the build log"
  [ -s "$TOPOLOGY_LOG" ] || { log "no topology log at $TOPOLOGY_LOG"; return 1; }

  local xdp_seen ipt_seen xdp_count xdp_ping ipt_ping
  xdp_seen="$(sed -n 's/^SUMMARY xdp_seen=\([0-9]*\).*/\1/p' "$TOPOLOGY_LOG" | head -1)"
  ipt_seen="$(sed -n 's/^SUMMARY .*ipt_seen=\([0-9]*\).*/\1/p' "$TOPOLOGY_LOG" | head -1)"
  xdp_count="$(sed -n 's/^SUMMARY .*xdp_count=\([0-9]*\).*/\1/p' "$TOPOLOGY_LOG" | head -1)"
  xdp_ping="$(sed -n 's/^SUMMARY .*xdp_ping=\([0-9]*\).*/\1/p' "$TOPOLOGY_LOG" | head -1)"
  ipt_ping="$(sed -n 's/^SUMMARY .*ipt_ping=\([0-9]*\).*/\1/p' "$TOPOLOGY_LOG" | head -1)"

  log "step 2: the verifier must have accepted the program"
  grep -qE 'xdp +name drop_icmp' "$TOPOLOGY_LOG"

  log "step 4: XDP must stop the ping"
  log "replies with XDP attached: ${xdp_ping:-none} (expect 0)"
  [ -n "$xdp_ping" ] && [ "$xdp_ping" -eq 0 ]

  log "step 4: an XDP-dropped packet must be invisible to tcpdump"
  log "echo requests captured: ${xdp_seen:-none} (expect 0)"
  [ -n "$xdp_seen" ] && [ "$xdp_seen" -eq 0 ]

  log "step 4: the program's map must show it actually ran"
  log "drops counted: ${xdp_count:-none} (expect > 0)"
  [ -n "$xdp_count" ] && [ "$xdp_count" -gt 0 ]

  log "step 5: iptables must also stop the ping"
  log "replies with the iptables rule: ${ipt_ping:-none} (expect 0)"
  [ -n "$ipt_ping" ] && [ "$ipt_ping" -eq 0 ]

  log "step 5: but an iptables-dropped packet must still be visible to tcpdump"
  log "echo requests captured: ${ipt_seen:-none} (expect > 0)"
  [ -n "$ipt_seen" ] && [ "$ipt_seen" -gt 0 ]

  {
    echo "XDP_DROP:       ping replies $xdp_ping, tcpdump saw $xdp_seen, map counted $xdp_count"
    echo "iptables DROP:  ping replies $ipt_ping, tcpdump saw $ipt_seen"
  } | tee "$RUN_DIR/result.txt" | tee -a "$LOG_FILE" >/dev/null

  write_verification "verified" "Both filters stopped the ping ($xdp_ping and $ipt_ping replies), but only one was observable: the XDP-dropped packets never reached h2's network stack and tcpdump captured $xdp_seen of them, while the BPF map counted $xdp_count drops proving the program ran; the iptables-dropped packets were captured $ipt_seen times because they were dropped after the stack had already received them."
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
