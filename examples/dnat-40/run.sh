#!/usr/bin/env bash
set -euo pipefail

LAB_ID="dnat-40"
TOPOLOGY="dnat-40.clab.yml"
CLIENT="clab-dnat-40-client"
GW="clab-dnat-40-gw"
SERVER="clab-dnat-40-server"
PUBLIC_IP="203.0.113.1"
PUBLIC_PORT="8080"
INTERNAL="10.0.0.2:80"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$LAB_DIR/../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/assets/dnat-40/runs/$RUN_ID}"
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

# Fetch the public address:port from the client; echo the body or "unreachable".
fetch() {
  docker exec "$CLIENT" curl -s --max-time 4 "http://$PUBLIC_IP:$PUBLIC_PORT/" 2>/dev/null | tr -d '\r\n' || true
}

verify() {
  log "starting the internal HTTP server (private 10.0.0.2:80)"
  docker exec "$SERVER" pkill -f "responder.py" >/dev/null 2>&1 || true
  docker exec -d "$SERVER" python3 /responder.py server
  sleep 1

  log "BEFORE DNAT: client hits the public $PUBLIC_IP:$PUBLIC_PORT (nothing published yet)"
  local before
  before="$(fetch)"
  echo "before: '${before:-<unreachable>}'" | tee "$RUN_DIR/result.txt" | tee -a "$LOG_FILE" >/dev/null
  log "before DNAT: '${before:-<unreachable>}' (expected empty — no service on the public port)"

  log "publishing the service: DNAT $PUBLIC_IP:$PUBLIC_PORT -> $INTERNAL"
  run_cmd docker exec "$GW" iptables -t nat -A PREROUTING -d "$PUBLIC_IP" -p tcp --dport "$PUBLIC_PORT" -j DNAT --to-destination "$INTERNAL"
  docker exec "$GW" iptables -t nat -L PREROUTING -n -v | tee "$RUN_DIR/nat-rules.txt" | tee -a "$LOG_FILE" >/dev/null

  log "AFTER DNAT: client hits the same public $PUBLIC_IP:$PUBLIC_PORT"
  local after
  after="$(fetch)"
  echo "after: '${after:-<unreachable>}'" | tee -a "$RUN_DIR/result.txt" | tee -a "$LOG_FILE" >/dev/null
  log "after DNAT: '${after:-<unreachable>}' (expected 'server' — forwarded to the internal host)"

  docker exec "$GW" conntrack -L 2>/dev/null | grep "dport=$PUBLIC_PORT" \
    | tee "$RUN_DIR/conntrack.txt" | tee -a "$LOG_FILE" >/dev/null || true

  log "checking the port forward"
  # Before publishing, the public port had no service.
  [ -z "$before" ]
  # After DNAT, the client reaches the internal server via the public address.
  [ "$after" = "server" ]
  # conntrack shows the destination was rewritten to the internal host:port.
  grep -q "10.0.0.2" "$RUN_DIR/conntrack.txt"

  write_verification "verified" "DNAT / port forwarding: the internal server ($INTERNAL, private) was published at the public $PUBLIC_IP:$PUBLIC_PORT. Before the rule the client got nothing on the public port; after 'iptables -t nat -A PREROUTING ... -j DNAT --to-destination $INTERNAL' the client reached the server through the public address ('server'), and conntrack showed the destination rewritten to the internal host. This is the inbound complement to the source NAT of Lab 20."
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
