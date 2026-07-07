#!/usr/bin/env bash
set -euo pipefail

LAB_ID="mss-37"
TOPOLOGY="mss-37.clab.yml"
CLIENT="clab-mss-37-client"
R="clab-mss-37-r"
SERVER="clab-mss-37-server"
SERVER_IP="10.0.8.2"
NARROW_MTU="1400"
EXPECT_CLAMPED=$((NARROW_MTU - 40))   # 1360
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/mss-37/runs/$RUN_ID}"
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

# Capture the MSS option of the client's SYN as seen at the server, then trigger
# a connection. Echoes the integer MSS (or empty).
capture_syn_mss() {
  local out="$1"
  docker exec "$SERVER" rm -f /tmp/syn.txt >/dev/null 2>&1 || true
  docker exec -d "$SERVER" sh -c \
    'tcpdump -i eth1 -n -c1 "tcp[tcpflags] & tcp-syn != 0 and tcp[tcpflags] & tcp-ack == 0" >/tmp/syn.txt 2>&1'
  sleep 1
  docker exec "$CLIENT" sh -c "curl -s --max-time 4 http://$SERVER_IP/ >/dev/null 2>&1" || true
  sleep 1
  docker cp "$SERVER:/tmp/syn.txt" "$out" >/dev/null 2>&1 || true
  grep -oE 'mss [0-9]+' "$out" 2>/dev/null | head -1 | awk '{print $2}'
}

verify() {
  log "starting an HTTP server on the server"
  docker exec "$SERVER" pkill -f "http.server" >/dev/null 2>&1 || true
  docker exec -d "$SERVER" sh -c "python3 -m http.server 80 >/dev/null 2>&1"
  sleep 1

  log "the r--server link MTU is ${NARROW_MTU}; the client link is 1500"
  docker exec "$R" ip -br link show eth2 | tee "$RUN_DIR/r-eth2.txt" | tee -a "$LOG_FILE" >/dev/null

  log "WITHOUT clamping: MSS in the client's SYN as seen at the server"
  local mss_before
  mss_before="$(capture_syn_mss "$RUN_DIR/syn-before.txt")"
  log "SYN MSS without clamping: ${mss_before:-?}"

  log "applying MSS clamping on r (mangle FORWARD, clamp to PMTU)"
  run_cmd docker exec "$R" iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
  docker exec "$R" iptables -t mangle -L FORWARD -n -v | tee "$RUN_DIR/mangle.txt" | tee -a "$LOG_FILE" >/dev/null

  log "WITH clamping: MSS in the client's SYN as seen at the server"
  local mss_after
  mss_after="$(capture_syn_mss "$RUN_DIR/syn-after.txt")"
  log "SYN MSS with clamping: ${mss_after:-?}"

  {
    echo "mss_before: ${mss_before:-NA}"
    echo "mss_after: ${mss_after:-NA}"
    echo "narrow_mtu: $NARROW_MTU"
    echo "expected_clamped: $EXPECT_CLAMPED"
  } | tee "$RUN_DIR/result.txt" | tee -a "$LOG_FILE" >/dev/null

  log "checking the router clamped the SYN's MSS to fit the narrow link"
  # The unclamped SYN advertises the client's local MSS (1500 - 40 = 1460).
  [ "${mss_before:-0}" -eq 1460 ]
  # After clamping, the router rewrote it down to fit the 1400-MTU link (1360).
  [ "${mss_after:-0}" -eq "$EXPECT_CLAMPED" ]
  # And it is strictly smaller than before.
  [ "${mss_after:-0}" -lt "${mss_before:-0}" ]

  write_verification "verified" "TCP MSS clamping: the client (1500-MTU link) advertised MSS ${mss_before} in its SYN. With 'TCPMSS --clamp-mss-to-pmtu' on r's FORWARD chain, r rewrote the SYN's MSS down to ${mss_after} to fit the ${NARROW_MTU}-MTU r--server link, so both endpoints send segments that always fit — avoiding fragmentation and PMTU blackholes."
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
