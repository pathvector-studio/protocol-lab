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
  $0 run dns-13
  $0 run dns-14
  $0 run tls-15
  $0 run wg-16
  $0 run dane-17
  $0 run vxlan-18
  $0 run trace-19
  $0 run nat-20
  $0 run gre-21
  $0 run dhcp-22
  $0 run ndp-23
  $0 run arp-24
  $0 run mtu-25
  $0 run vlan-26
  $0 run http-27
  $0 run qos-28
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
  $0 deploy dns-13
  $0 deploy dns-14
  $0 deploy tls-15
  $0 deploy wg-16
  $0 deploy dane-17
  $0 deploy vxlan-18
  $0 deploy trace-19
  $0 deploy nat-20
  $0 deploy gre-21
  $0 deploy dhcp-22
  $0 deploy ndp-23
  $0 deploy arp-24
  $0 deploy mtu-25
  $0 deploy vlan-26
  $0 deploy http-27
  $0 deploy qos-28
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
  $0 verify dns-13
  $0 verify dns-14
  $0 verify tls-15
  $0 verify wg-16
  $0 verify dane-17
  $0 verify vxlan-18
  $0 verify trace-19
  $0 verify nat-20
  $0 verify gre-21
  $0 verify dhcp-22
  $0 verify ndp-23
  $0 verify arp-24
  $0 verify mtu-25
  $0 verify vlan-26
  $0 verify http-27
  $0 verify qos-28
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
  $0 destroy dns-13
  $0 destroy dns-14
  $0 destroy tls-15
  $0 destroy wg-16
  $0 destroy dane-17
  $0 destroy vxlan-18
  $0 destroy trace-19
  $0 destroy nat-20
  $0 destroy gre-21
  $0 destroy dhcp-22
  $0 destroy ndp-23
  $0 destroy arp-24
  $0 destroy mtu-25
  $0 destroy vlan-26
  $0 destroy http-27
  $0 destroy qos-28
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
  $0 doctor dns-13
  $0 doctor dns-14
  $0 doctor tls-15
  $0 doctor wg-16
  $0 doctor dane-17
  $0 doctor vxlan-18
  $0 doctor trace-19
  $0 doctor nat-20
  $0 doctor gre-21
  $0 doctor dhcp-22
  $0 doctor ndp-23
  $0 doctor arp-24
  $0 doctor mtu-25
  $0 doctor vlan-26
  $0 doctor http-27
  $0 doctor qos-28
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
  dns-13)
    cd "$REPO_ROOT/examples/dns-13"
    ./run.sh "$ACTION"
    ;;
  dns-14)
    cd "$REPO_ROOT/examples/dns-14"
    ./run.sh "$ACTION"
    ;;
  tls-15)
    cd "$REPO_ROOT/examples/tls-15"
    ./run.sh "$ACTION"
    ;;
  wg-16)
    cd "$REPO_ROOT/examples/wg-16"
    ./run.sh "$ACTION"
    ;;
  dane-17)
    cd "$REPO_ROOT/examples/dane-17"
    ./run.sh "$ACTION"
    ;;
  vxlan-18)
    cd "$REPO_ROOT/examples/vxlan-18"
    ./run.sh "$ACTION"
    ;;
  trace-19)
    cd "$REPO_ROOT/examples/trace-19"
    ./run.sh "$ACTION"
    ;;
  nat-20)
    cd "$REPO_ROOT/examples/nat-20"
    ./run.sh "$ACTION"
    ;;
  gre-21)
    cd "$REPO_ROOT/examples/gre-21"
    ./run.sh "$ACTION"
    ;;
  dhcp-22)
    cd "$REPO_ROOT/examples/dhcp-22"
    ./run.sh "$ACTION"
    ;;
  ndp-23)
    cd "$REPO_ROOT/examples/ndp-23"
    ./run.sh "$ACTION"
    ;;
  arp-24)
    cd "$REPO_ROOT/examples/arp-24"
    ./run.sh "$ACTION"
    ;;
  mtu-25)
    cd "$REPO_ROOT/examples/mtu-25"
    ./run.sh "$ACTION"
    ;;
  vlan-26)
    cd "$REPO_ROOT/examples/vlan-26"
    ./run.sh "$ACTION"
    ;;
  http-27)
    cd "$REPO_ROOT/examples/http-27"
    ./run.sh "$ACTION"
    ;;
  qos-28)
    cd "$REPO_ROOT/examples/qos-28"
    ./run.sh "$ACTION"
    ;;
  mcast-29)
    cd "$REPO_ROOT/examples/mcast-29"
    ./run.sh "$ACTION"
    ;;
  cc-30)
    cd "$REPO_ROOT/examples/cc-30"
    ./run.sh "$ACTION"
    ;;
  anycast-31)
    cd "$REPO_ROOT/examples/anycast-31"
    ./run.sh "$ACTION"
    ;;
  ecmp-32)
    cd "$REPO_ROOT/examples/ecmp-32"
    ./run.sh "$ACTION"
    ;;
  lb-33)
    cd "$REPO_ROOT/examples/lb-33"
    ./run.sh "$ACTION"
    ;;
  ospf-34)
    cd "$REPO_ROOT/examples/ospf-34"
    ./run.sh "$ACTION"
    ;;
  bfd-35)
    cd "$REPO_ROOT/examples/bfd-35"
    ./run.sh "$ACTION"
    ;;
  fw-36)
    cd "$REPO_ROOT/examples/fw-36"
    ./run.sh "$ACTION"
    ;;
  mss-37)
    cd "$REPO_ROOT/examples/mss-37"
    ./run.sh "$ACTION"
    ;;
  pbr-38)
    cd "$REPO_ROOT/examples/pbr-38"
    ./run.sh "$ACTION"
    ;;
  rpf-39)
    cd "$REPO_ROOT/examples/rpf-39"
    ./run.sh "$ACTION"
    ;;
  dnat-40)
    cd "$REPO_ROOT/examples/dnat-40"
    ./run.sh "$ACTION"
    ;;
  dnsrr-41)
    cd "$REPO_ROOT/examples/dnsrr-41"
    ./run.sh "$ACTION"
    ;;
  dns-views-42)
    cd "$REPO_ROOT/examples/dns-views-42"
    ./run.sh "$ACTION"
    ;;
  *)
    echo "[protocol-lab] ERROR: unsupported lab id: $LAB_ID" >&2
    exit 1
    ;;
esac
