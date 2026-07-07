# Examples

This directory contains runnable examples used by the labs. They are intentionally small so you can inspect every config file before starting a topology.

日本語: このディレクトリには、Labで使う実行可能な最小例を入れています。topologyを起動する前に、設定ファイルを読み切れるサイズに保っています。

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

## Safety

Examples are designed for closed local environments. They use documentation prefixes and private ASNs. Do not connect these lab topologies to a production network or advertise their routes to the public Internet.

日本語: Examplesは閉じたローカル環境で動かす前提です。documentation prefix と private ASN を使います。本番ネットワークへ接続したり、実インターネットへ経路広告したりしないでください。
