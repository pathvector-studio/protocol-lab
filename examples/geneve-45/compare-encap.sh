#!/bin/sh
# Lab 45: run GENEVE and VXLAN over the same underlay and compare them byte
# for byte.
#
# Two namespaces sit on one underlay subnet. Each gets *both* a geneve0 and a
# vxlan0 interface with the same VNI, so the only thing that differs between
# the two overlays is the encapsulation itself.
set -eu

UNDERLAY=10.30.0
GENEVE_NET=192.168.100
VXLAN_NET=192.168.200
VNI=100

say() { printf '\n=== %s ===\n' "$*"; }
run() { printf '+ %s\n' "$*"; sh -c "$*"; }

# ---------------------------------------------------------------------------
say "step 1: an underlay of two hosts"
# ---------------------------------------------------------------------------
ip link add br-u type bridge
ip link set br-u up
i=1
for n in h1 h2; do
  ip netns add "$n"
  ip link add "veth-$n" type veth peer name "tmp-$n"
  ip link set "tmp-$n" netns "$n"
  ip netns exec "$n" ip link set "tmp-$n" name eth0
  ip netns exec "$n" sysctl -qw net.ipv6.conf.all.disable_ipv6=1
  sysctl -qw "net.ipv6.conf.veth-$n.disable_ipv6=1"
  ip link set "veth-$n" master br-u
  ip link set "veth-$n" up
  ip netns exec "$n" sh -c "ip addr add $UNDERLAY.$i/24 dev eth0; ip link set eth0 up"
  printf '+ netns %s: underlay %s.%s\n' "$n" "$UNDERLAY" "$i"
  i=$((i + 1))
done
run "ip netns exec h1 ping -c 2 -W 1 $UNDERLAY.2"

# ---------------------------------------------------------------------------
say "step 2: two overlays with the same VNI over that one underlay"
# ---------------------------------------------------------------------------
for h in 1 2; do
  o=$((3 - h))
  ip netns exec "h$h" ip link add gnv0 type geneve id "$VNI" remote "$UNDERLAY.$o"
  ip netns exec "h$h" ip link add vx0 type vxlan id "$VNI" remote "$UNDERLAY.$o" dstport 4789
  ip netns exec "h$h" sh -c "ip addr add $GENEVE_NET.$h/24 dev gnv0; ip link set gnv0 up"
  ip netns exec "h$h" sh -c "ip addr add $VXLAN_NET.$h/24 dev vx0;  ip link set vx0 up"
  printf '+ netns h%s: gnv0 %s.%s (GENEVE, vni %s) / vx0 %s.%s (VXLAN, vni %s)\n' \
    "$h" "$GENEVE_NET" "$h" "$VNI" "$VXLAN_NET" "$h" "$VNI"
done

# ---------------------------------------------------------------------------
say "step 3: the kernel sized the two tunnels differently"
# ---------------------------------------------------------------------------
# GENEVE subtracts its own overhead from the underlay MTU. This VXLAN device,
# created with an explicit remote and no underlay dev, was left at 1500 — which
# is a real-world blackhole waiting to happen (see Lab 25 and Lab 37).
for d in eth0 gnv0 vx0; do
  printf 'mtu %s = %s\n' "$d" "$(ip netns exec h1 cat "/sys/class/net/$d/mtu")"
done
MTU_GNV="$(ip netns exec h1 cat /sys/class/net/gnv0/mtu)"
MTU_VX="$(ip netns exec h1 cat /sys/class/net/vx0/mtu)"

# capture <filter> <outfile> <target-ip> [extra tcpdump args]
capture_ping() {
  filter="$1"; out="$2"; target="$3"; shift 3
  ip netns exec h1 timeout 8 tcpdump -i eth0 -nn -c 1 "$@" "$filter" >"$out" 2>/dev/null &
  cap_pid=$!
  sleep 1.5
  ip netns exec h1 ping -c 1 -W 2 "$target" >/dev/null 2>&1 || true
  sleep 3
  kill "$cap_pid" 2>/dev/null || true
  wait "$cap_pid" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
say "step 4: the same ICMP, wrapped two different ways"
# ---------------------------------------------------------------------------
echo "-- GENEVE (UDP 6081) --"
capture_ping "udp port 6081" /tmp/gnv.txt "$GENEVE_NET.2"
cat /tmp/gnv.txt
echo "-- VXLAN (UDP 4789) --"
capture_ping "udp port 4789" /tmp/vx.txt "$VXLAN_NET.2"
cat /tmp/vx.txt

# Both must carry the inner payload in the clear: encapsulation is not
# encryption, the same point Lab 18 and Lab 21 made.
grep -q 6081 /tmp/gnv.txt
grep -q 4789 /tmp/vx.txt

# ---------------------------------------------------------------------------
say "step 5: the 8 bytes that differ"
# ---------------------------------------------------------------------------
# The outer IP header is 20 bytes and UDP is 8, so the encapsulation header
# starts at offset 0x1c in these dumps.
echo "-- GENEVE header bytes --"
capture_ping "udp port 6081" /tmp/gnvx.txt "$GENEVE_NET.2" -x
sed -n '1,4p' /tmp/gnvx.txt
echo "-- VXLAN header bytes --"
capture_ping "udp port 4789" /tmp/vxx.txt "$VXLAN_NET.2" -x
sed -n '1,4p' /tmp/vxx.txt

cat <<'NOTE'

reading the 8 bytes at offset 0x1c:

  GENEVE  00      00      6558          000064    00
          |       |       |             |         reserved
          |       |       |             VNI = 100
          |       |       Protocol Type = 0x6558 (Ethernet)
          |       flags (O, C)
          Ver=0 / Opt Len=0   <-- the extension point

  VXLAN   08      000000  000064        00
          |       |       |             reserved
          |       |       VNI = 100
          |       reserved
          flags, I bit set

GENEVE spends two of its eight bytes on a Protocol Type and an option length.
VXLAN spends them on reserved zeroes. That is the whole argument for GENEVE:
it can say what it carries, and it can be extended without a new protocol.
NOTE

# ---------------------------------------------------------------------------
say "step 6: the outer source port is a flow hash, not a constant"
# ---------------------------------------------------------------------------
# The encapsulator hashes the *inner* flow into the outer UDP source port, so
# ECMP (Lab 32) can spread tunnelled flows across paths without looking inside.
ip netns exec h1 timeout 10 tcpdump -i eth0 -nn -c 6 udp port 6081 >/tmp/flow.txt 2>/dev/null &
cap_pid=$!
sleep 1.5
for p in 7001 7002 7003; do
  ip netns exec h1 sh -c "echo probe | nc -u -w1 $GENEVE_NET.2 $p" >/dev/null 2>&1 || true
done
sleep 3
kill "$cap_pid" 2>/dev/null || true
wait "$cap_pid" 2>/dev/null || true
echo "outer source ports seen for three different inner flows:"
PORTS="$(grep -o "$UNDERLAY\.1\.[0-9]* > $UNDERLAY\.2\.6081" /tmp/flow.txt | sed 's/.*\.1\.\([0-9]*\) .*/\1/' | sort -u)"
echo "$PORTS"
DISTINCT="$(printf '%s\n' "$PORTS" | grep -c . || true)"
echo "distinct outer source ports: ${DISTINCT:-0} (expect 2 or more)"

printf '\nSUMMARY geneve_mtu=%s vxlan_mtu=%s distinct_sports=%s\n' \
  "$MTU_GNV" "$MTU_VX" "${DISTINCT:-0}"

say "comparison complete"
