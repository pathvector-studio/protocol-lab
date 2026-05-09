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
  $0 deploy bgp-01
  $0 deploy bgp-02
  $0 deploy bgp-03
  $0 deploy rpki-04
  $0 verify bgp-01
  $0 verify bgp-02
  $0 verify bgp-03
  $0 verify rpki-04
  $0 capture bgp-01
  $0 capture bgp-02
  $0 capture bgp-03
  $0 destroy bgp-01
  $0 destroy bgp-02
  $0 destroy bgp-03
  $0 destroy rpki-04
  $0 doctor bgp-01
  $0 doctor bgp-02
  $0 doctor bgp-03
  $0 doctor rpki-04
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
  *)
    echo "[protocol-lab] ERROR: unsupported lab id: $LAB_ID" >&2
    exit 1
    ;;
esac
