#!/bin/sh
# Lab 43: build container networking by hand, one primitive at a time.
#
# Runs inside the privileged lab container. The container's own network stack
# stands in for "the host"; the two namespaces we create stand in for "two
# containers". Nothing here is Docker-specific — this is what Docker does.
set -eu

RED=red
BLUE=blue
RED_IP=10.10.0.2
BLUE_IP=10.10.0.3
PREFIX=24
BRIDGE=br0

say() { printf '\n=== %s ===\n' "$*"; }
run() { printf '+ %s\n' "$*"; sh -c "$*"; }

# ---------------------------------------------------------------------------
say "step 1: two empty namespaces"
# ---------------------------------------------------------------------------
# A netns is a whole private network stack: its own interfaces, routing table,
# ARP cache and firewall rules. A fresh one has only a down loopback.
run "ip netns add $RED"
run "ip netns add $BLUE"
run "ip netns list"

printf '\n-- what red can see at birth --\n'
run "ip netns exec $RED ip link show"
run "ip netns exec $RED ip route show || true"

# ---------------------------------------------------------------------------
say "step 2: veth pairs — virtual cables"
# ---------------------------------------------------------------------------
# A veth pair is two interfaces joined back to back: whatever enters one end
# leaves the other. We keep one end on the host side and push the other into
# the namespace, which is exactly the "cable" between host and container.
# The peer is created with a temporary name because the lab container already
# owns an eth0, and names must be unique *within* a namespace. Once the peer is
# inside red, "eth0" is free again there — so we rename it. Both namespaces end
# up with an interface called eth0, and they are different interfaces.
run "ip link add veth-red type veth peer name tmp-red"
run "ip link set tmp-red netns $RED"
run "ip netns exec $RED ip link set tmp-red name eth0"
run "ip link add veth-blue type veth peer name tmp-blue"
run "ip link set tmp-blue netns $BLUE"
run "ip netns exec $BLUE ip link set tmp-blue name eth0"

run "ip netns exec $RED  sh -c 'ip addr add $RED_IP/$PREFIX dev eth0;  ip link set eth0 up; ip link set lo up'"
run "ip netns exec $BLUE sh -c 'ip addr add $BLUE_IP/$PREFIX dev eth0; ip link set eth0 up; ip link set lo up'"
run "ip link set veth-red up"
run "ip link set veth-blue up"

printf '\n-- red now has an address and an on-link route --\n'
run "ip netns exec $RED ip addr show eth0"
run "ip netns exec $RED ip route show"

# ---------------------------------------------------------------------------
say "step 3: the cables are plugged into nothing"
# ---------------------------------------------------------------------------
# Both namespaces are configured and on the same subnet, but the host-side ends
# dangle. There is no switch, so red's ARP request for blue reaches veth-red
# and stops there. This failure is the point of the step.
printf '+ ip netns exec %s ping -c 2 -W 1 %s\n' "$RED" "$BLUE_IP"
if ip netns exec "$RED" ping -c 2 -W 1 "$BLUE_IP"; then
  echo "UNEXPECTED: ping succeeded before the bridge existed" >&2
  exit 1
fi
echo "(expected) unreachable: configured, but not connected"

printf '\n-- red asked, and got no answer --\n'
run "ip netns exec $RED ip neigh show"

# ---------------------------------------------------------------------------
say "step 4: a bridge — the missing switch"
# ---------------------------------------------------------------------------
# A Linux bridge is a software Ethernet switch. Enslaving both host-side veth
# ends to it finally joins the two cables.
run "ip link add $BRIDGE type bridge"
run "ip link set $BRIDGE up"
run "ip link set veth-red master $BRIDGE"
run "ip link set veth-blue master $BRIDGE"
run "ip link show master $BRIDGE"

# ---------------------------------------------------------------------------
say "step 5: the same ping, now that a switch exists"
# ---------------------------------------------------------------------------
printf '+ ip netns exec %s ping -c 3 -W 1 %s\n' "$RED" "$BLUE_IP"
ip netns exec "$RED" ping -c 3 -W 1 "$BLUE_IP"

printf '\n-- red resolved blue to a MAC --\n'
run "ip netns exec $RED ip neigh show"

# ---------------------------------------------------------------------------
say "step 6: the bridge learned where each address lives"
# ---------------------------------------------------------------------------
# Forwarding both ways made the bridge record which port each source MAC came
# from. This table is what Lab 44 takes apart.
run "bridge fdb show br $BRIDGE | grep -v permanent"

# ---------------------------------------------------------------------------
say "step 7: the namespaces really are separate stacks"
# ---------------------------------------------------------------------------
# Same interface name, different interface. Separate routing tables. A private
# loopback each. This is the isolation that makes a container feel like a host.
run "ip netns exec $RED  ip -o addr show eth0"
run "ip netns exec $BLUE ip -o addr show eth0"
run "ip netns exec $RED ping -c 1 -W 1 127.0.0.1"

say "topology built"
