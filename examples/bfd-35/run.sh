#!/usr/bin/env bash
set -euo pipefail

LAB_ID="bfd-35"
TOPOLOGY="bfd-35.clab.yml"
R1="clab-bfd-35-r1"
TARGET_IP="10.0.30.1"
NH_DIRECT="10.0.13.2"   # r1 -> r3 direct
NH_VIA_R2="10.0.12.2"   # r1 -> r2 (reconverged path)
RECONVERGE_BUDGET_MS="5000"   # BFD detection ~900ms; well under OSPF's 40s dead timer
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/bfd-35/runs/$RUN_ID}"
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

now_ms() { date +%s%N | cut -b1-13; }
route_nexthop() { docker exec "$R1" ip route get "$TARGET_IP" 2>/dev/null | grep -oE 'via 10\.0\.1[0-9.]+' | head -1; }

# Wait until r1 has two BFD sessions up and the target routes over the direct link.
wait_ready() {
  local i up
  for i in $(seq 1 60); do
    up="$(docker exec "$R1" vtysh -c 'show bfd peers' 2>/dev/null | grep -c 'Status: up' || true)"
    if [ "${up:-0}" -ge 2 ] && route_nexthop | grep -q "$NH_DIRECT"; then
      log "r1 has $up BFD sessions up and routes to the target via the direct link (after ${i}s)"
      return 0
    fi
    sleep 1
  done
  log "timed out waiting for BFD sessions / direct route"
  return 1
}

verify() {
  log "waiting for OSPF+BFD to come up"
  wait_ready

  docker exec "$R1" vtysh -c "show bfd peers" \
    2>/dev/null | tee "$RUN_DIR/bfd-before.txt" | tee -a "$LOG_FILE" >/dev/null
  docker exec "$R1" vtysh -c "show ip ospf interface eth2" \
    2>/dev/null | grep -iE "Timer intervals" | tee "$RUN_DIR/ospf-timers.txt" | tee -a "$LOG_FILE" >/dev/null

  log "reachability before the failure"
  docker exec "$R1" ping -c2 -W1 "$TARGET_IP" >/dev/null 2>&1 && log "target reachable via direct link"

  # Record that the link is up (carrier present) — this is a SILENT failure.
  local link_state
  link_state="$(docker exec "$R1" ip -br link show eth2 2>/dev/null)"
  echo "$link_state" | tee "$RUN_DIR/eth2-link.txt" | tee -a "$LOG_FILE" >/dev/null

  log "SILENT failure: dropping all packets on r1's eth2 (the link stays UP)"
  run_cmd docker exec "$R1" sh -c 'iptables -A INPUT -i eth2 -j DROP; iptables -A OUTPUT -o eth2 -j DROP'

  log "timing how long BFD takes to detect it and OSPF to reconverge onto r2"
  local start elapsed nh reconverged=0
  start="$(now_ms)"
  local i
  for i in $(seq 1 100); do
    nh="$(route_nexthop)"
    if printf '%s' "$nh" | grep -q "$NH_VIA_R2"; then
      elapsed=$(( $(now_ms) - start )); reconverged=1
      log "reconverged to $nh after ~${elapsed} ms"
      break
    fi
    sleep 0.2
  done

  # The link is still up even though forwarding is dead — that is the whole point.
  docker exec "$R1" ip -br link show eth2 2>/dev/null | tee "$RUN_DIR/eth2-link-after.txt" | tee -a "$LOG_FILE" >/dev/null

  log "reachability after reconvergence (via r2)"
  local after_ok=0
  docker exec "$R1" ping -c2 -W1 "$TARGET_IP" >/dev/null 2>&1 && { after_ok=1; log "target still reachable via r2"; }

  log "restoring the link (flushing the drop rules)"
  docker exec "$R1" sh -c 'iptables -D INPUT -i eth2 -j DROP; iptables -D OUTPUT -o eth2 -j DROP' >/dev/null 2>&1 || true

  {
    echo "reconverged: $reconverged"
    echo "elapsed_ms: ${elapsed:-NA}"
    echo "link_at_failure: $link_state"
  } >"$RUN_DIR/result.txt"

  log "checking BFD detected the silent failure fast"
  # Two BFD sessions were up with sub-second timers.
  [ "$(docker exec "$R1" vtysh -c 'show bfd peers' 2>/dev/null | grep -c 'Status: up')" -ge 1 ]
  grep -q "Transmission interval: 300ms" "$RUN_DIR/bfd-before.txt"
  # The link was still UP (LOWER_UP) at the moment of failure — a silent break.
  printf '%s' "$link_state" | grep -q "LOWER_UP"
  # OSPF reconverged onto r2, and did so far faster than its 40s dead timer.
  [ "$reconverged" = 1 ]
  [ "${elapsed:-999999}" -lt "$RECONVERGE_BUDGET_MS" ]
  # And the target stayed reachable.
  [ "$after_ok" = 1 ]

  write_verification "verified" "BFD: r1 ran OSPF with BFD (300ms x3 = ~900ms detection) on both adjacencies. A silent failure (all packets dropped on eth2 while the link stayed UP) was caught by BFD and OSPF reconverged onto r2 in ~${elapsed:-?} ms — versus OSPF's 40s dead timer without BFD. The target stayed reachable."
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
