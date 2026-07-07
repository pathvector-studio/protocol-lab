# Examples

This directory contains runnable examples used by the labs. They are intentionally small so you can inspect every config file before starting a topology.

Ã¦ÂÂ¥Ã¦ÂÂ¬Ã¨ÂªÂ: Ã£ÂÂÃ£ÂÂ®Ã£ÂÂÃ£ÂÂ£Ã£ÂÂ¬Ã£ÂÂ¯Ã£ÂÂÃ£ÂÂªÃ£ÂÂ«Ã£ÂÂ¯Ã£ÂÂLabÃ£ÂÂ§Ã¤Â½Â¿Ã£ÂÂÃ¥Â®ÂÃ¨Â¡ÂÃ¥ÂÂ¯Ã¨ÂÂ½Ã£ÂÂªÃ¦ÂÂÃ¥Â°ÂÃ¤Â¾ÂÃ£ÂÂÃ¥ÂÂ¥Ã£ÂÂÃ£ÂÂ¦Ã£ÂÂÃ£ÂÂ¾Ã£ÂÂÃ£ÂÂtopologyÃ£ÂÂÃ¨ÂµÂ·Ã¥ÂÂÃ£ÂÂÃ£ÂÂÃ¥ÂÂÃ£ÂÂ«Ã£ÂÂÃ¨Â¨Â­Ã¥Â®ÂÃ£ÂÂÃ£ÂÂ¡Ã£ÂÂ¤Ã£ÂÂ«Ã£ÂÂÃ¨ÂªÂ­Ã£ÂÂ¿Ã¥ÂÂÃ£ÂÂÃ£ÂÂÃ£ÂÂµÃ£ÂÂ¤Ã£ÂÂºÃ£ÂÂ«Ã¤Â¿ÂÃ£ÂÂ£Ã£ÂÂ¦Ã£ÂÂÃ£ÂÂ¾Ã£ÂÂÃ£ÂÂ

## Available Examples

- [`bgp-01/`](bgp-01/): a two-router eBGP topology using FRRouting and containerlab.
- [`bgp-02/`](bgp-02/): the same two-router eBGP shape, with route withdrawal and reannouncement.
- [`bgp-03/`](bgp-03/): a three-router eBGP topology with two origins for the same prefix.
- [`rpki-04/`](rpki-04/): a local RPKI origin validation lab using FRRouting, StayRTR, and containerlab.
- [`dns-05/`](dns-05/): a five-node DNS hierarchy (client, recursive resolver, root, TLD, authoritative) using BIND9, netshoot, and containerlab.
- [`dns-06/`](dns-06/): the same DNS hierarchy, tuned for observing caching, TTL countdown, and NXDOMAIN negative caching.
- [`tcp-07/`](tcp-07/): a two-node point-to-point link using netshoot and containerlab for capturing one TCP connection's handshake and teardown.
- [`tcp-08/`](tcp-08/): the same two-node link with `tc netem` loss and delay, for observing retransmission, RTT, and windowing.
- [`tls-09/`](tls-09/): a two-node link running `openssl s_server`/`s_client` for capturing a TLS 1.3 handshake with SNI and ALPN.
- [`http-10/`](http-10/): a two-node link with a small Python HTTP server for reading methods, status codes, headers, and cache behavior (ETag / 304).
- [`quic-11/`](quic-11/): a two-node link with a Caddy server (HTTP/1.1, HTTP/2, HTTP/3) for comparing stream multiplexing over TCP vs QUIC.
- [`e2e-12/`](e2e-12/): a client, a DNS resolver, and a web server, so one `curl https://www.example.lab/` crosses DNS, TCP, TLS, and HTTP in order.
- [`dns-13/`](dns-13/): a client, a validating resolver, and an authoritative server holding a DNSSEC-signed `example.lab`, for watching a validated answer (AD flag) and a tampered one rejected with SERVFAIL.
- [`dns-14/`](dns-14/): a client and a BIND server offering Do53, DoT (853), and DoH (443), for watching the same answer travel in cleartext vs inside TLS.
- [`tls-15/`](tls-15/): a client and an openssl s_server that requires a client certificate (mTLS), for watching mutual authentication succeed and a certless client be rejected.
- [`wg-16/`](wg-16/): two nodes joined by a WireGuard tunnel, for watching a ping cross it as encrypted UDP on the underlay while the inner ICMP is only visible inside wg0.
- [`dane-17/`](dane-17/): a client, a DNSSEC-signed authoritative server with a TLSA record, and a TLS web server, for validating a certificate against DNS (DANE) and rejecting an impostor.
- [`vxlan-18/`](vxlan-18/): two nodes joined by a VXLAN Layer-2 overlay, for watching a ping travel as VXLAN over UDP with the inner frame visible in the clear (contrast with WireGuard).
- [`trace-19/`](trace-19/): a client, two Linux routers, and a server, so traceroute maps the path hop by hop via TTL and ICMP time-exceeded.
- [`nat-20/`](nat-20/): a private client, a masquerading NAT router, and a public server, so you can see the server observe the NAT public address (never the private client) and the NAT conntrack mapping.
- [`gre-21/`](gre-21/): two nodes joined by a GRE tunnel (IP proto 47), completing the tunnel trilogy Ã¢ÂÂ an unencrypted L3 tunnel whose inner IP is visible on the underlay.
- [`dhcp-22/`](dhcp-22/): a client with no address and a DHCP server (udhcpd), for watching the four-message DORA exchange assign a lease on the wire.
- [`ndp-23/`](ndp-23/): two IPv6 nodes, for watching Neighbor Discovery (Neighbor Solicitation to a solicited-node multicast, Neighbor Advertisement with the MAC) resolve a neighbor â ARP's IPv6 successor.
- [`arp-24/`](arp-24/): two IPv4 nodes, for watching ARP (broadcast request, unicast reply) resolve a neighbor MAC — the IPv4 original that NDP replaced.
- [`mtu-25/`](mtu-25/): a client, a router with a smaller-MTU link, and a server, for watching an oversized DF packet draw an ICMP fragmentation-needed reply and the client learn the path MTU.
- [`vlan-26/`](vlan-26/): two nodes with 802.1Q VLAN subinterfaces on one link, for watching tagged frames (vlan 100 / vlan 200) keep two virtual LANs isolated on one wire.
- [`http-27/`](http-27/): a client and a small HTTP app, for watching a 302 redirect (Location) and a Set-Cookie / Cookie round-trip.
- [`qos-28/`](qos-28/): a client and an iperf3 server, for measuring throughput before and after a tc token-bucket shaper caps the link.
- [`mcast-29/`](mcast-29/): a sender, two receivers, and a Linux-bridge switch, for watching one UDP multicast stream reach both receivers (that joined via IGMP) as a single copy on the wire.
- [`cc-30/`](cc-30/): a client and an iperf3 server over a lossy, long-RTT bottleneck (tc netem), for comparing CUBIC vs BBR congestion control — loss-based CUBIC collapses while model-based BBR fills the pipe.
- [`anycast-31/`](anycast-31/): a client, a router, and two FRR servers that both announce one VIP (10.0.0.100/32) via BGP, for watching routing pick the nearer instance and fail over to the other when it withdraws.
- [`ecmp-32/`](ecmp-32/): two FRR routers joined by two parallel links (BGP maximum-paths), for watching many TCP flows hash across both equal-cost links — and pile onto one when L4 hashing is off.
- [`lb-33/`](lb-33/): a client, an IPVS load balancer with one VIP, and three backends, for watching round-robin (NAT mode) spread connections evenly across the pool while the client only ever sees the VIP.
- [`ospf-34/`](ospf-34/): three FRR routers in an OSPF area-0 triangle with a target network behind r3, for watching adjacencies reach Full, SPF pick the lowest-cost path, and the route reconverge when the direct link fails.
- [`bfd-35/`](bfd-35/): the OSPF triangle plus BFD on every adjacency, for watching a silent forwarding failure (link up, packets dropped) get caught in ~900 ms instead of OSPF's 40 s dead timer.
- [`fw-36/`](fw-36/): a client, a stateful firewall router, and a server, for watching conntrack allow an outbound-initiated connection and its reply while dropping an unsolicited inbound one.
- [`mss-37/`](mss-37/): a client, a router, and a server across a link with a smaller MTU, for watching the router clamp the TCP SYN's MSS (1460 → 1360) so segments fit the narrowest link.

## Safety

Examples are designed for closed local environments. They use documentation prefixes and private ASNs. Do not connect these lab topologies to a production network or advertise their routes to the public Internet.

Ã¦ÂÂ¥Ã¦ÂÂ¬Ã¨ÂªÂ: ExamplesÃ£ÂÂ¯Ã©ÂÂÃ£ÂÂÃ£ÂÂÃ£ÂÂ­Ã£ÂÂ¼Ã£ÂÂ«Ã£ÂÂ«Ã§ÂÂ°Ã¥Â¢ÂÃ£ÂÂ§Ã¥ÂÂÃ£ÂÂÃ£ÂÂÃ¥ÂÂÃ¦ÂÂÃ£ÂÂ§Ã£ÂÂÃ£ÂÂdocumentation prefix Ã£ÂÂ¨ private ASN Ã£ÂÂÃ¤Â½Â¿Ã£ÂÂÃ£ÂÂ¾Ã£ÂÂÃ£ÂÂÃ¦ÂÂ¬Ã§ÂÂªÃ£ÂÂÃ£ÂÂÃ£ÂÂÃ£ÂÂ¯Ã£ÂÂ¼Ã£ÂÂ¯Ã£ÂÂ¸Ã¦ÂÂ¥Ã§Â¶ÂÃ£ÂÂÃ£ÂÂÃ£ÂÂÃ£ÂÂÃ¥Â®ÂÃ£ÂÂ¤Ã£ÂÂ³Ã£ÂÂ¿Ã£ÂÂ¼Ã£ÂÂÃ£ÂÂÃ£ÂÂÃ£ÂÂ¸Ã§ÂµÂÃ¨Â·Â¯Ã¥ÂºÂÃ¥ÂÂÃ£ÂÂÃ£ÂÂÃ£ÂÂÃ£ÂÂÃ£ÂÂªÃ£ÂÂÃ£ÂÂ§Ã£ÂÂÃ£ÂÂ Ã£ÂÂÃ£ÂÂÃ£ÂÂ
