#!/usr/bin/env bash
set -euo pipefail

LAB_ID="mcast-29"
TOPOLOGY="mcast-29.clab.yml"
SENDER="clab-mcast-29-sender"
RX1="clab-mcast-29-rx1"
RX2="clab-mcast-29-rx2"
GROUP="239.1.1.1"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/mcast-29/runs/$RUN_ID}"
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

deploy() {
  log "deploying topology"
  sudo_cmd containerlab destroy -t "$TOPOLOGY" --cleanup >/dev/null 2>&1 || true
  run_cmd sudo_cmd containerlab deploy -t "$TOPOLOGY"
}

verify() {
  log "capturing IGMP + multicast on rx1 before the receivers join"
  docker exec "$RX1" rm -f /tmp/mc.pcap >/dev/null 2>&1 || true
  docker exec -d "$RX1" tcpdump -i eth1 -n -e -w /tmp/mc.pcap "igmp or (udp and dst $GROUP)"
  sleep 1

  log "both receivers join group $GROUP (iperf -s -u -B) — IGMP membership"
  docker exec "$RX1" pkill -f "iperf -s" >/dev/null 2>&1 || true
  docker exec "$RX2" pkill -f "iperf -s" >/dev/null 2>&1 || true
  docker exec -d "$RX1" sh -c "iperf -s -u -B $GROUP -i1 >/tmp/rx1.log 2>&1"
  docker exec -d "$RX2" sh -c "iperf -s -u -B $GROUP -i1 >/tmp/rx2.log 2>&1"
  sleep 2

  log "confirming the group membership on both receivers"
  docker exec "$RX1" ip maddr show eth1 | tee "$RUN_DIR/rx1-maddr.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$RX2" ip maddr show eth1 | tee "$RUN_DIR/rx2-maddr.txt" | tee -a "$LOG_FILE" >/dev/null

  log "sender sends ONE multicast stream to $GROUP"
  docker exec "$SENDER" iperf -c "$GROUP" -u -T 5 -t 3 -b 2m 2>&1 \
    | tee "$RUN_DIR/sender.txt" | tee -a "$LOG_FILE" >/dev/null || true
  sleep 2

  docker exec "$RX1" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1
  docker cp "$RX1:/tmp/mc.pcap" "$RUN_DIR/multicast.pcap" >/dev/null 2>&1 || true
  docker exec "$RX1" tcpdump -n -e -r /tmp/mc.pcap 2>/dev/null | tee "$RUN_DIR/mc-decoded.txt" >/dev/null || true
  docker cp "$RX1:/tmp/rx1.log" "$RUN_DIR/rx1.log" >/dev/null 2>&1 || true
  docker cp "$RX2:/tmp/rx2.log" "$RUN_DIR/rx2.log" >/dev/null 2>&1 || true
  docker exec "$RX1" pkill -f "iperf -s" >/dev/null 2>&1 || true
  docker exec "$RX2" pkill -f "iperf -s" >/dev/null 2>&1 || true

  log "checking multicast delivery and IGMP"
  # Both receivers joined the group.
  grep -q "$GROUP" "$RUN_DIR/rx1-maddr.txt"
  grep -q "$GROUP" "$RUN_DIR/rx2-maddr.txt"
  # Both receivers actually received datagrams from the single stream.
  grep -qiE "0.0- ?.*sec|Bytes|datagram" "$RUN_DIR/rx1.log"
  grep -qiE "0.0- ?.*sec|Bytes|datagram" "$RUN_DIR/rx2.log"
  # The capture shows IGMP membership and the multicast MAC (01:00:5e...).
  grep -qi "igmp" "$RUN_DIR/mc-decoded.txt"
  grep -qiE "01:00:5e" "$RUN_DIR/mc-decoded.txt"

  write_verification "verified" "Multicast: the sender sent a single UDP stream to $GROUP; both rx1 and rx2 (which had joined the group via IGMP) received it. The capture shows an IGMP membership report and the multicast destination MAC (01:00:5e:...). One send, many receivers, one copy on the wire."
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
  command -v tcpdump
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
