#!/bin/sh
# Lab 44: watch a Linux bridge learn, and watch the flooding stop.
#
# Three namespaces hang off one bridge. a pings b; c is the bystander whose only
# job is to tell us whether the frame was flooded to every port or forwarded to
# just one. Because the frame is not addressed to c, c must capture in
# promiscuous mode to see it at all — which is exactly the point.
set -eu

BRIDGE=br0
SUBNET=10.20.0
AGEING_SECONDS=5

say() { printf '\n=== %s ===\n' "$*"; }
run() { printf '+ %s\n' "$*"; sh -c "$*"; }

dynamic_fdb() {
  # "permanent" entries are the ports' own addresses; "self" belongs to the
  # bridge device. Neither is learned, so neither is interesting here.
  bridge fdb show br "$BRIDGE" | grep -v permanent | grep -v self || true
}

# ---------------------------------------------------------------------------
say "step 1: three namespaces on one bridge"
# ---------------------------------------------------------------------------
run "ip link add $BRIDGE type bridge"
run "ip link set $BRIDGE up"

i=1
for n in a b c; do
  ip netns add "$n"
  ip link add "veth-$n" type veth peer name "tmp-$n"
  ip link set "tmp-$n" netns "$n"
  ip netns exec "$n" ip link set "tmp-$n" name eth0
  # IPv6 is switched off on purpose. Link-local autoconfiguration chatters as
  # soon as an interface comes up, and that chatter teaches the bridge before
  # the experiment starts — the FDB would never be empty to begin with.
  ip netns exec "$n" sysctl -qw net.ipv6.conf.all.disable_ipv6=1
  sysctl -qw "net.ipv6.conf.veth-$n.disable_ipv6=1"
  ip link set "veth-$n" master "$BRIDGE"
  ip link set "veth-$n" up
  ip netns exec "$n" sh -c "ip addr add $SUBNET.$i/24 dev eth0; ip link set eth0 up"
  printf '+ netns %s: %s.%s on eth0, host end veth-%s enslaved to %s\n' "$n" "$SUBNET" "$i" "$n" "$BRIDGE"
  i=$((i + 1))
done

MAC_A="$(ip netns exec a cat /sys/class/net/eth0/address)"
MAC_B="$(ip netns exec b cat /sys/class/net/eth0/address)"
MAC_C="$(ip netns exec c cat /sys/class/net/eth0/address)"
printf '\na=%s  b=%s  c=%s\n' "$MAC_A" "$MAC_B" "$MAC_C"

# Static neighbour entries remove ARP from the experiment. ARP requests are
# broadcast and are *always* flooded, learned or not, so leaving them in would
# blur the one thing we are measuring: what happens to a *unicast* frame.
run "ip netns exec a ip neigh replace $SUBNET.2 lladdr $MAC_B dev eth0 nud permanent"
run "ip netns exec b ip neigh replace $SUBNET.1 lladdr $MAC_A dev eth0 nud permanent"

# ---------------------------------------------------------------------------
say "step 2: the forwarding database starts empty"
# ---------------------------------------------------------------------------
printf '+ bridge fdb show br %s (learned entries only)\n' "$BRIDGE"
if [ -z "$(dynamic_fdb)" ]; then
  echo "(no learned entries — the bridge has seen nothing yet)"
else
  dynamic_fdb
  echo "UNEXPECTED: the FDB already holds learned entries" >&2
  exit 1
fi

# probe <count> -> number of echo requests that reached c
probe() {
  ip netns exec c timeout 6 tcpdump -i eth0 -nn -e -Q in icmp >/tmp/cap 2>/dev/null &
  cap_pid=$!
  sleep 1.5
  ip netns exec a ping -c "$1" -i 0.3 -W 1 "$SUBNET.2" >/dev/null 2>&1 || true
  sleep 2
  kill "$cap_pid" 2>/dev/null || true
  wait "$cap_pid" 2>/dev/null || true
  seen="$(grep -c 'ICMP echo request' /tmp/cap 2>/dev/null || true)"
  printf '%s' "${seen:-0}"
}

# ---------------------------------------------------------------------------
say "step 3: unknown unicast is flooded"
# ---------------------------------------------------------------------------
# a sends one frame to b's MAC. The bridge has never seen that address, so it
# cannot know which port it lives behind — and it does the only safe thing:
# sends it out of every port except the one it arrived on. c gets a copy.
echo "a -> b, one packet, with b's address unknown to the bridge"
SEEN_UNKNOWN="$(probe 1)"
echo "frames c received that were addressed to b: $SEEN_UNKNOWN (expect 1 — flooded)"
printf '\n-- what c captured --\n'
grep 'ICMP echo request' /tmp/cap || true
[ "$SEEN_UNKNOWN" -ge 1 ]

# ---------------------------------------------------------------------------
say "step 4: forwarding it taught the bridge where both hosts are"
# ---------------------------------------------------------------------------
# a's frame taught the bridge where a is (source MAC on ingress port veth-a).
# b's reply taught it where b is. Learning is always from the SOURCE address.
dynamic_fdb

# ---------------------------------------------------------------------------
say "step 5: the same traffic is no longer flooded"
# ---------------------------------------------------------------------------
echo "a -> b, three packets, with b's address now learned"
SEEN_LEARNED="$(probe 3)"
echo "frames c received that were addressed to b: $SEEN_LEARNED (expect 0 — forwarded to one port)"
[ "$SEEN_LEARNED" -eq 0 ]

# ---------------------------------------------------------------------------
say "step 6: forget b, and the flooding comes back"
# ---------------------------------------------------------------------------
# Proof that the difference is the FDB entry and nothing else: delete just that
# one entry and repeat the identical test.
run "bridge fdb del $MAC_B dev veth-b master"
dynamic_fdb
SEEN_AGAIN="$(probe 1)"
echo "frames c received after deleting b's entry: $SEEN_AGAIN (expect 1 — flooded again)"
[ "$SEEN_AGAIN" -ge 1 ]

# ---------------------------------------------------------------------------
say "step 7: entries expire on their own"
# ---------------------------------------------------------------------------
# A real switch must forget, or a machine that moves ports would be unreachable
# until reboot. The default ageing time is 300s; we shorten it to watch it work.
run "ip link set $BRIDGE type bridge ageing_time $((AGEING_SECONDS * 100))"
echo "ageing_time set to ${AGEING_SECONDS}s; entries present now:"
dynamic_fdb
echo "waiting $((AGEING_SECONDS * 2 + 2))s without traffic..."
sleep $((AGEING_SECONDS * 2 + 2))
echo "entries after the wait:"
if [ -z "$(dynamic_fdb)" ]; then
  echo "(all learned entries aged out)"
else
  dynamic_fdb
fi

say "observation complete"
