#!/bin/sh
# Lab 46: drop the same packet in two places and see which drop tcpdump can see.
#
# h2 is the target. The sender is the container's own root namespace. The same
# ICMP is blocked twice: once by an XDP program on h2's ingress, once by an
# iptables INPUT rule. Both stop the ping. Only one of them is visible to a
# packet capture running on h2 — and that difference is the lesson.
set -eu

OBJ=/lab/drop_icmp.bpf.o
# bpffs deliberately lives outside /sys: "ip netns exec" re-mounts sysfs for the
# target namespace, which would hide a pin under /sys/fs/bpf.
BPFFS=/bpf
PIN="$BPFFS/drop_icmp"
NET=10.40.0

say() { printf '\n=== %s ===\n' "$*"; }
run() { printf '+ %s\n' "$*"; sh -c "$*"; }

# capture_probe <tag> -> echo requests that reached h2's network stack
capture_probe() {
  ip netns exec h2 timeout 6 tcpdump -i eth0 -nn -U icmp >"/tmp/$1.txt" 2>/dev/null &
  cap_pid=$!
  sleep 1.5
  ping -c 2 -W 1 "$NET.2" >/dev/null 2>&1 || true
  sleep 4
  kill "$cap_pid" 2>/dev/null || true
  wait "$cap_pid" 2>/dev/null || true
  grep -c 'ICMP echo request' "/tmp/$1.txt" 2>/dev/null || true
}

ping_received() {
  ping -c 2 -W 1 "$NET.2" 2>&1 | sed -n 's/.*[0-9]* packets transmitted, \([0-9]*\) received.*/\1/p'
}

# ---------------------------------------------------------------------------
say "step 1: a target to shoot at"
# ---------------------------------------------------------------------------
mkdir -p "$BPFFS"
mount -t bpf bpf "$BPFFS"
ip netns add h2
ip link add veth-h1 type veth peer name tmp
ip link set tmp netns h2
ip netns exec h2 ip link set tmp name eth0
ip addr add "$NET.1/24" dev veth-h1
ip link set veth-h1 up
ip netns exec h2 sh -c "ip addr add $NET.2/24 dev eth0; ip link set eth0 up"
sleep 1
BASE="$(ping_received)"
echo "baseline: $BASE of 2 replies"
[ "$BASE" = "2" ]

# ---------------------------------------------------------------------------
say "step 2: load the program (the verifier has to agree first)"
# ---------------------------------------------------------------------------
# Loading is separate from attaching. At this point the program exists in the
# kernel and has been proven safe, but no packet has touched it.
# "pinmaps" is required: loading pins the program only, and the lab needs the
# counter map pinned too so it can be read back after attach.
run "bpftool prog load $OBJ $PIN pinmaps $BPFFS"
run "bpftool prog show pinned $PIN"

# ---------------------------------------------------------------------------
say "step 3: attach it to h2's ingress"
# ---------------------------------------------------------------------------
run "ip netns exec h2 bpftool net attach xdpgeneric pinned $PIN dev eth0"
run "ip netns exec h2 bpftool net show dev eth0"

# ---------------------------------------------------------------------------
say "step 4: XDP_DROP — the ping dies and the capture stays empty"
# ---------------------------------------------------------------------------
XDP_PING="$(ping_received)"
echo "ping with XDP attached: $XDP_PING of 2 replies"
XDP_SEEN="$(capture_probe xdp)"
echo "echo requests tcpdump saw on h2: ${XDP_SEEN:-0}"
echo "-- the program's own counter --"
run "bpftool map dump pinned $BPFFS/icmp_drops"
XDP_COUNT="$(bpftool map dump pinned "$BPFFS/icmp_drops" | sed -n 's/.*"value": \([0-9]*\).*/\1/p' | head -1)"

# ---------------------------------------------------------------------------
say "step 5: the same drop, one layer later"
# ---------------------------------------------------------------------------
run "ip netns exec h2 bpftool net detach xdpgeneric dev eth0"
run "ip netns exec h2 iptables -A INPUT -p icmp -j DROP"
IPT_PING="$(ping_received)"
echo "ping with the iptables rule: $IPT_PING of 2 replies"
IPT_SEEN="$(capture_probe ipt)"
echo "echo requests tcpdump saw on h2: ${IPT_SEEN:-0}"
run "ip netns exec h2 iptables -L INPUT -v -n"

# ---------------------------------------------------------------------------
say "step 6: same outcome, different place in the path"
# ---------------------------------------------------------------------------
cat <<NOTE
                          ping replies    tcpdump on h2
  no filter                    $BASE               (n/a)
  XDP_DROP                     $XDP_PING               ${XDP_SEEN:-0}     <- never reached the stack
  iptables -j DROP             $IPT_PING               ${IPT_SEEN:-0}     <- arrived, then was dropped

  XDP runs before the kernel allocates an sk_buff. tcpdump taps the stack after
  that allocation, so a packet XDP drops cannot appear there at all. The BPF map
  counted $XDP_COUNT drops, which is how we know the packets were handled rather
  than lost somewhere else.
NOTE

printf '\nSUMMARY xdp_seen=%s ipt_seen=%s xdp_count=%s xdp_ping=%s ipt_ping=%s\n' \
  "${XDP_SEEN:-0}" "${IPT_SEEN:-0}" "${XDP_COUNT:-0}" "$XDP_PING" "$IPT_PING"

say "observation complete"
