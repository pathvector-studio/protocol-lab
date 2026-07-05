#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<USAGE
Usage:
  $0 run bgp-01
  $0 run bgp-02
  $0 run bgp-03
  $0 run rpki-04
  $0 run dns-05
  $0 run dns-06
  $0 run tcp-07
  $0 run tcp-08
  $0 run tls-09
  $0 run http-10
  $0 run quic-11
  $0 run e2e-12
  $0 deploy bgp-01
  $0 deploy bgp-02
  $0 deploy bgp-03
  $0 deploy rpki-04
  $0 deploy dns-05
  $0 deploy dns-06
  $0 deploy tcp-07
  $0 deploy tcp-08
  $0 deploy tls-09
  $0 deploy http-10
  $0 deploy quic-11
  $0 deploy e2e-12
  $0 verify bgp-01
  $0 verify bgp-02
  $0 verify bgp-03
  $0 verify rpki-04
  $0 verify dns-05
  $0 verify dns-06
  $0 verify tcp-07
  $0 verify tcp-08
  $0 verify tls-09
  $0 verify http-10
  $0 verify quic-11
  $0 verify e2e-12
  $0 capture bgp-01
  $0 capture bgp-02
  $0 capture bgp-03
  $0 destroy bgp-01
  $0 destroy bgp-02
  $0 destroy bgp-03
  $0 destroy rpki-04
  $0 destroy dns-05
  $0 destroy dns-06
  $0 destroy tcp-07
  $0 destroy tcp-08
  $0 destroy tls-09
  $0 destroy http-10
  $0 destroy quic-11
  $0 destroy e2e-12
  $0 doctor bgp-01
  $0 doctor bgp-02
  $0 doctor bgp-03
  $0 doctor rpki-04
  $0 doctor dns-05
  $0 doctor dns-06
  $0 doctor tcp-07
  $0 doctor tcp-08
  $0 doctor tls-09
  $0 doctor http-10
  $0 doctor quic-11
  $0 doctor e2e-12
USAGE
}

ACTION="${1:-}"
LAB_ID="${2:-}"

if [[ -z "$ACTION" || -z "$LAB_ID" ]]; then
  usage >&2
  exit 1
fi

case "$LAB_ID" in
  bgp-01)
    cd "$REPO_ROOT/examples/bgp-01"
    ./run.sh "$ACTION"
    ;;
  bgp-02)
    cd "$REPO_ROOT/examples/bgp-02"
    ./run.sh "$ACTION"
    ;;
  bgp-03)
    cd "$REPO_ROOT/examples/bgp-03"
    ./run.sh "$ACTION"
    ;;
  rpki-04)
    cd "$REPO_ROOT/examples/rpki-04"
    ./run.sh "$ACTION"
    ;;
  dns-05)
    cd "$REPO_ROOT/examples/dns-05"
    ./run.sh "$ACTION"
    ;;
  dns-06)
    cd "$REPO_ROOT/examples/dns-06"
    ./run.sh "$ACTION"
    ;;
  tcp-07)
    cd "$REPO_ROOT/examples/tcp-07"
    ./run.sh "$ACTION"
    ;;
  tcp-08)
    cd "$REPO_ROOT/examples/tcp-08"
    ./run.sh "$ACTION"
    ;;
  tls-09)
    cd "$REPO_ROOT/examples/tls-09"
    ./run.sh "$ACTION"
    ;;
  http-10)
    cd "$REPO_ROOT/examples/http-10"
    ./run.sh "$ACTION"
    ;;
  quic-11)
    cd "$REPO_ROOT/examples/quic-11"
    ./run.sh "$ACTION"
    ;;
  e2e-12)
    cd "$REPO_ROOT/examples/e2e-12"
    ./run.sh "$ACTION"
    ;;
  *)
    echo "[protocol-lab] ERROR: unsupported lab id: $LAB_ID" >&2
    exit 1
    ;;
esac
