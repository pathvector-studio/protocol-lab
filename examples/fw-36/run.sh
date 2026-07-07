#!/usr/bin/env bash
set -euo pipefail

LAB_ID="fw-36"
TOPOLOGY="fw-36.clab.yml"
CLIENT="clab-fw-36-client"
FW="clab-fw-36-fw"
SERVER="clab-fw-36-server"
CLIENT_IP="10.0.9.2"
SERVER_IP="10.0.8.2"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/fw-36/runs/$RUN_ID}"
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

# curl a URL from a container; echo "ok" if it returned data, "blocked" otherwise.
try_http() {
  local node="$1" url="$2"
  if docker exec "$node" curl -s --max-time 4 "$url" >/dev/null 2>&1; then
    echo "ok"
  else
    echo "blocked"
  fi
}

verify() {
  log "installing the stateful firewall on fw (default-drop FORWARD)"
  run_cmd docker exec "$FW" sh -c '
    iptables -F FORWARD
    iptables -P FORWARD DROP
    iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -i eth1 -m conntrack --ctstate NEW -j ACCEPT
  '
  docker exec "$FW" iptables -L FORWARD -n -v --line-numbers \
    | tee "$RUN_DIR/forward-rules.txt" | tee -a "$LOG_FILE" >/dev/null

  log "starting HTTP responders on client and server"
  docker exec -d "$CLIENT" python3 /responder.py client
  docker exec -d "$SERVER" python3 /responder.py server
  sleep 1

  log "client -> server (outbound-initiated: SYN is NEW-from-inside, reply is ESTABLISHED)"
  local out_in
  out_in="$(try_http "$CLIENT" "http://$SERVER_IP/")"
  log "client -> server: $out_in"

  # Capture the tracked flow while it is fresh.
  docker exec "$FW" conntrack -L 2>/dev/null | grep -E "src=$CLIENT_IP .*dst=$SERVER_IP" \
    | tee "$RUN_DIR/conntrack.txt" | tee -a "$LOG_FILE" >/dev/null || true

  log "server -> client (unsolicited inbound: SYN is NEW-from-outside)"
  local in_out
  in_out="$(try_http "$SERVER" "http://$CLIENT_IP/")"
  log "server -> client: $in_out"

  {
    echo "client_to_server: $out_in"
    echo "server_to_client: $in_out"
  } | tee "$RUN_DIR/result.txt" | tee -a "$LOG_FILE" >/dev/null

  log "checking the stateful policy"
  # FORWARD policy is default-drop.
  docker exec "$FW" iptables -L FORWARD -n | head -1 | grep -q "policy DROP"
  # Outbound-initiated connection succeeds (and its reply is allowed by state).
  [ "$out_in" = "ok" ]
  # Unsolicited inbound connection is dropped.
  [ "$in_out" = "blocked" ]
  # conntrack tracked the allowed flow (both directions recorded on one entry).
  grep -q "src=$CLIENT_IP" "$RUN_DIR/conntrack.txt"

  write_verification "verified" "Stateful firewall: fw's FORWARD policy is DROP, accepting only ESTABLISHED/RELATED flows and NEW connections from the client side. The client reached the server ($out_in) because its SYN was NEW-from-inside and the reply matched the tracked (ESTABLISHED) flow; the server could not reach the client ($in_out) because its SYN was an unsolicited NEW-from-outside. conntrack recorded the one allowed flow with both directions."
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
