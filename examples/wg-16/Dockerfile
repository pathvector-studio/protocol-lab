# netshoot + wireguard-tools for Protocol Lab #16.
#
# netshoot (Alpine) already ships ip, tcpdump, ping, and tshark; it does not
# ship the WireGuard userspace tool. We add wireguard-tools so `wg` can set
# keys and peers. The WireGuard data path itself is the host kernel module,
# which autoloads when the first `wg0` interface is created.
FROM nicolaka/netshoot:latest

RUN apk add --no-cache wireguard-tools
