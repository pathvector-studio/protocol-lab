# Protocol Lab

Protocol Lab is a free learning project for network protocols. Each lab starts from a small part of an RFC, turns it into a runnable experiment, and uses command output or packet captures to explain what happened.

日本語: Protocol Lab は、RFCを読み、手を動かし、パケットやログを見ながらネットワークプロトコルを学ぶための無料教材です。小さな実験を通して、読んだ仕様と観察できる挙動を結びつけます。

## Start Here

The first track is BGP/RPKI. Start with:

- [BGP Lab 01: One Prefix Announcement You Can Explain](labs/bgp-01-as-prefix-announcement.md)
- [RFC 4271 Reading Guide for BGP Lab 01](rfc-notes/bgp-rfc4271.md)
- [BGP Lab 02: Watch a Route Appear, Disappear, and Come Back](labs/bgp-02-update-nexthop-withdrawal.md)
- [RFC 4271 Reading Guide for BGP Lab 02](rfc-notes/bgp-rfc4271-lab02.md)
- [BGP Lab 03: Competing Origins and the First Route-Leak Question](labs/bgp-03-competing-origins-route-leaks.md)
- [RFC 4271 Reading Guide for BGP Lab 03](rfc-notes/bgp-rfc4271-lab03.md)
- [RPKI Lab 04: ROAs and Origin Validation](labs/rpki-04-roa-origin-validation.md)
- [RPKI Origin Validation Reading Guide for Lab 04](rfc-notes/rpki-origin-validation.md)
- [DNS Lab 05: Recursive Resolution You Can Trace](labs/dns-05-recursive-resolution.md)
- [DNS Recursive Resolution Reading Guide for Lab 05](rfc-notes/dns-recursive-resolution.md)
- [DNS Lab 06: Caching, TTL, and the Answer That Wasn't There](labs/dns-06-caching-ttl-negative.md)
- [DNS Caching, TTL, and Negative Answers Reading Guide for Lab 06](rfc-notes/dns-caching-ttl-negative.md)
- [TCP Lab 07: One Connection, From SYN to FIN](labs/tcp-07-handshake-teardown.md)
- [TCP Handshake and Teardown Reading Guide for Lab 07](rfc-notes/tcp-handshake-teardown.md)
- [TCP Lab 08: Loss, Retransmission, and the Window](labs/tcp-08-retransmission-windowing-loss.md)
- [TCP Retransmission and Windowing Reading Guide for Lab 08](rfc-notes/tcp-retransmission-windowing.md)
- [TLS Lab 09: What Is Visible Before Encryption](labs/tls-09-handshake-certificates.md)
- [TLS Handshake and Certificates Reading Guide for Lab 09](rfc-notes/tls-handshake-certificates.md)
- [HTTP Lab 10: One Exchange, Read in the Clear](labs/http-10-requests-responses-caching.md)
- [HTTP Requests, Responses, and Caching Reading Guide for Lab 10](rfc-notes/http-requests-responses-caching.md)
- [Lab 11: HTTP/2 Streams and the Jump to QUIC](labs/quic-11-http2-quic-streams.md)
- [HTTP/2, HTTP/3, and QUIC Streams Reading Guide for Lab 11](rfc-notes/http2-quic-streams.md)
- [Lab 12: One Web Request, End to End](labs/e2e-12-end-to-end.md)
- [End-to-End Web Request Reading Guide for Lab 12](rfc-notes/e2e-web-request.md)
- [DNS Lab 13: DNSSEC — Signatures, Trust Anchors, and the AD Flag](labs/dns-13-dnssec-validation.md)
- [DNSSEC Validation Reading Guide for Lab 13](rfc-notes/dns-dnssec-validation.md)
- [DNS Lab 14: Encrypted DNS — DoT and DoH](labs/dns-14-encrypted-dns-dot-doh.md)
- [Encrypted DNS Reading Guide for Lab 14](rfc-notes/dns-encrypted-dot-doh.md)
- [TLS Lab 15: Mutual TLS — Proving the Client Too](labs/tls-15-mutual-tls.md)
- [Mutual TLS Reading Guide for Lab 15](rfc-notes/tls-mutual-tls.md)
- [Lab 16: WireGuard — an Encrypted Tunnel You Can See Into](labs/wg-16-wireguard-tunnel.md)
- [WireGuard Reading Guide for Lab 16](rfc-notes/wg-wireguard-tunnel.md)
- [Lab 17: DANE — When DNS Vouches for the Certificate](labs/dane-17-dane-tlsa.md)
- [DANE / TLSA Reading Guide for Lab 17](rfc-notes/dane-tlsa.md)
- [Lab 18: VXLAN — an Overlay You Can Read on the Wire](labs/vxlan-18-l2-overlay.md)
- [VXLAN Overlay Reading Guide for Lab 18](rfc-notes/vxlan-overlay.md)
- [Lab 19: traceroute and TTL — Mapping a Path Hop by Hop](labs/trace-19-traceroute-ttl.md)
- [traceroute and TTL Reading Guide for Lab 19](rfc-notes/traceroute-ttl.md)
- [Lab 20: NAT — One Public Address for Many](labs/nat-20-source-translation.md)
- [NAT Reading Guide for Lab 20](rfc-notes/nat-source-translation.md)
- [Lab 21: GRE — an Unencrypted Layer-3 Tunnel](labs/gre-21-l3-tunnel.md)
- [GRE Tunnel Reading Guide for Lab 21](rfc-notes/gre-tunnel.md)
- [Lab 22: DHCP — Four Messages for an Address](labs/dhcp-22-dora.md)
- [DHCP Reading Guide for Lab 22](rfc-notes/dhcp-dora.md)
- [Lab 23: IPv6 Neighbor Discovery — ARP's Successor](labs/ndp-23-neighbor-discovery.md)
- [IPv6 Neighbor Discovery Reading Guide for Lab 23](rfc-notes/ndp-neighbor-discovery.md)
- [Lab 24: ARP — the IPv4 Original](labs/arp-24-address-resolution.md)
- [ARP Reading Guide for Lab 24](rfc-notes/arp-address-resolution.md)
- [Lab 25: MTU and Path MTU Discovery](labs/mtu-25-path-mtu-discovery.md)
- [Path MTU Discovery Reading Guide for Lab 25](rfc-notes/mtu-path-mtu-discovery.md)
- [Lab 26: VLANs — Two Networks on One Wire](labs/vlan-26-8021q.md)
- [802.1Q VLAN Reading Guide for Lab 26](rfc-notes/vlan-8021q.md)
- [Lab 27: HTTP Redirects and Cookies](labs/http-27-redirects-cookies.md)
- [HTTP Redirects and Cookies Reading Guide for Lab 27](rfc-notes/http-redirects-cookies.md)
- [Lab 28: QoS — Shaping a Link with a Token Bucket](labs/qos-28-traffic-shaping.md)
- [Traffic Shaping Reading Guide for Lab 28](rfc-notes/qos-traffic-shaping.md)
- [Lab 29: Multicast and IGMP — One Sender, Many Receivers](labs/mcast-29-igmp.md)
- [Multicast and IGMP Reading Guide for Lab 29](rfc-notes/multicast-igmp.md)
- [Lab 30: TCP Congestion Control — CUBIC vs BBR on a Lossy Path](labs/cc-30-congestion-control.md)
- [TCP Congestion Control Reading Guide for Lab 30](rfc-notes/tcp-congestion-control.md)
- [Full learning roadmap](ROADMAP.md)

Lab 01 builds a two-router eBGP topology, advertises one documentation prefix, and helps you explain the resulting route in terms of NLRI, AS_PATH, NEXT_HOP, and ORIGIN.

最初のトラックは BGP/RPKI です。Lab 01 では、2台の仮想ルータで eBGP を動かし、1つの documentation prefix を広告します。Lab 02 では、その route が現れ、withdraw で消え、再広告で戻るところを観察します。Lab 03 では、同じ prefix が複数の origin AS から見える状態を作ります。Lab 04 では、ROA/VRP と origin validation の3状態を観察します。全体像は [12-lab learning roadmap](ROADMAP.md) を見てください。

## What You Will Do

- Read the RFC sections that matter for one small concept.
- Run a minimal local experiment.
- Inspect routing tables, logs, and packet captures.
- Connect the observed output back to protocol terms.
- Answer short review questions before moving to the next lab.

日本語:

- 1つの概念に必要なRFCの章を読む。
- 小さなローカル実験を動かす。
- routing table、ログ、pcapを観察する。
- 観察結果をプロトコル用語に対応づける。
- 確認問題で理解を固めてから次へ進む。

## Requirements

Most hands-on labs assume a Linux environment with:

- Docker
- containerlab
- tcpdump
- Wireshark or tshark

On Ubuntu/Debian you can install all of these at once:

```bash
sudo bash scripts/install-lab-tools.sh --pull
```

Then log out and back in (or run `newgrp docker`) so the `docker` group applies, and check with `./scripts/labctl.sh doctor tcp-07`.

macOS users should run the labs inside a Linux VM, WSL-style environment, or another Linux host where containerlab can create network namespaces.

日本語: ハンズオンは Linux 環境を前提にしています。Ubuntu/Debian なら `sudo bash scripts/install-lab-tools.sh --pull` で必要なツール(Docker、containerlab、tshark など)を一括で導入できます。実行後は再ログイン(または `newgrp docker`)で `docker` グループを反映し、`./scripts/labctl.sh doctor tcp-07` で確認します。macOS の場合は、Linux VM や Linux ホスト上で実行してください。containerlab が network namespace を作れる環境が必要です。

## Safety

Labs use documentation address space such as `203.0.113.0/24` and private ASNs such as `65001`. These examples are for closed local labs only. Do not announce them to the public Internet.

日本語: Labでは `203.0.113.0/24` のような documentation address と `65001` のような private ASN を使います。これは閉じたローカル実験用です。実インターネットへ広告しないでください。

## Repository Guide

| Path | What it contains |
|---|---|
| `labs/` | Hands-on labs with commands, expected observations, explanations, and review questions |
| `rfc-notes/` | Reading guides that map RFC sections to each lab |
| `examples/` | Minimal containerlab, FRRouting, and script examples used by the labs |
| `scripts/` | Small helper scripts for running labs in a Linux environment |
| `assets/` | Optional diagrams, screenshots, and small packet captures referenced by lessons |

日本語:

| パス | 内容 |
|---|---|
| `labs/` | コマンド、期待される観察結果、解説、確認問題を含むハンズオン |
| `rfc-notes/` | Labと対応するRFC reading guide |
| `examples/` | Labで使う containerlab / FRRouting / script の最小例 |
| `scripts/` | Linux環境でLabを実行するための補助スクリプト |
| `assets/` | 教材で参照する図、スクリーンショット、小さなpcap |

## Learning Track

Protocol Lab begins with BGP/RPKI and then expands toward the protocols that make up a web request. The full sequence is described in [ROADMAP.md](ROADMAP.md).

| Track | Labs | Outcome |
|---|---:|---|
| BGP/RPKI | 01-04 | Explain route announcements, UPDATEs, competing origins, and origin validation |
| DNS | 05-06 | Trace recursive resolution, caching, TTLs, and negative answers |
| TCP | 07-08 | Read handshakes, teardown, retransmission, windowing, and loss recovery |
| TLS / HTTP / QUIC | 09-12 | Follow an encrypted web request across transport and application layers |

日本語: Protocol Lab は BGP/RPKI から始まり、Web request を構成する DNS、TCP、TLS、HTTP、QUIC へ進みます。全12回の流れは [ROADMAP.md](ROADMAP.md) にあります。

| トラック | Lab | 到達点 |
|---|---:|---|
| BGP/RPKI | 01-04 | 経路広告、UPDATE、competing origin、origin validation を説明する |
| DNS | 05-06 | 再帰問い合わせ、cache、TTL、negative answer を追う |
| TCP | 07-08 | handshake、切断、再送、windowing、loss recovery を packet trace から読む |
| TLS / HTTP / QUIC | 09-12 | 暗号化された Web request を transport と application layer に分けて追う |
