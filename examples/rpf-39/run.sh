#!/usr/bin/env bash
set -euo pipefail

LAB_ID="rpf-39"
TOPOLOGY="rpf-39.clab.yml"
R="clab-rpf-39-r"
TARGET="clab-rpf-39-target"
ATTACKER="clab-rpf-39-attacker"
TARGET_IP="10.0.1.20"
SPOOFED_SRC="10.0.1.10"   # a net-A address, spoofed from net B
REAL_SRC="10.0.2.10"      # the attacker's real net-B address
PINGS="3"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/rpf-39/runs/$RUN_ID}"
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

set_rpfilter() {
  local v="$1"
  docker exec "$R" sh -c "sysctl -w net.ipv4.conf.all.rp_filter=$v; sysctl -w net.ipv4.conf.eth2.rp_filter=$v" >/dev/null 2>&1
}

# Send $PINGS ICMP echoes from the attacker with a given source address and
# echo how many actually reached the target (captured on the target). The
# capture filter restricts to that source, so every captured packet is one of
# our echo requests that made it through.
probe() {
  local src="$1" tag="$2" n
  docker exec "$TARGET" rm -f /tmp/cap.pcap >/dev/null 2>&1 || true
  docker exec -d "$TARGET" sh -c "tcpdump -i eth1 -n 'icmp and src $src' -w /tmp/cap.pcap 2>/dev/null" || true
  sleep 1
  docker exec "$ATTACKER" nping --icmp -c "$PINGS" --source-ip "$src" "$TARGET_IP" >/dev/null 2>&1 || true
  sleep 1
  docker exec "$TARGET" pkill -INT tcpdump >/dev/null 2>&1 || true
  sleep 1
  docker cp "$TARGET:/tmp/cap.pcap" "$RUN_DIR/${tag}.pcap" >/dev/null 2>&1 || true
  n="$(docker exec "$TARGET" sh -c 'tcpdump -n -r /tmp/cap.pcap 2>/dev/null | wc -l' 2>/dev/null || echo 0)"
  echo "${n:-0}"
}

verify() {
  log "STRICT reverse path filtering on r (rp_filter=1)"
  set_rpfilter 1
  docker exec "$R" sh -c 'sysctl net.ipv4.conf.all.rp_filter net.ipv4.conf.eth2.rp_filter' \
    | tee "$RUN_DIR/rpfilter-on.txt" | tee -a "$LOG_FILE" >/dev/null

  log "attacker spoofs a net-A source ($SPOOFED_SRC) from net B -> target"
  local spoof_strict
  spoof_strict="$(probe "$SPOOFED_SRC" spoofed-strict)"
  log "spoofed packets reaching target (strict): ${spoof_strict:-0} (expect 0 — dropped by rp_filter)"

  log "attacker sends from its REAL source ($REAL_SRC) -> target (should pass)"
  local legit_strict
  legit_strict="$(probe "$REAL_SRC" legit-strict)"
  log "legit packets reaching target (strict): ${legit_strict:-0} (expect >0 — not spoofed)"

  log "disabling reverse path filtering (rp_filter=0)"
  set_rpfilter 0
  local spoof_off
  spoof_off="$(probe "$SPOOFED_SRC" spoofed-off)"
  log "spoofed packets reaching target (rp_filter off): ${spoof_off:-0} (expect >0 — now forwarded)"

  {
    echo "spoofed_strict: ${spoof_strict:-0}"
    echo "legit_strict: ${legit_strict:-0}"
    echo "spoofed_off: ${spoof_off:-0}"
  } | tee "$RUN_DIR/result.txt" | tee -a "$LOG_FILE" >/dev/null

  log "checking reverse path filtering blocked only the spoofed source"
  # Strict rp_filter drops the spoofed packets at ingress.
  [ "${spoof_strict:-1}" -eq 0 ]
  # But legitimate traffic (real source on the right interface) still passes.
  [ "${legit_strict:-0}" -ge 1 ]
  # With rp_filter off, the same spoofed packets are forwarded.
  [ "${spoof_off:-0}" -ge 1 ]

  write_verification "verified" "Reverse path filtering: the attacker on net B spoofed a net-A source ($SPOOFED_SRC). With strict rp_filter, r dropped those packets at ingress (0 reached the target) because the route back to $SPOOFED_SRC is via eth1, not the eth2 they arrived on — while legitimate traffic from the attacker's real source still passed ($legit_strict reached). With rp_filter off, the spoofed packets were forwarded ($spoof_off reached)."
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
