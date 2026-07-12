# Protocol Lab Roadmap

This roadmap shows the labs in Protocol Lab. The sequence starts with BGP and RPKI, then expands into DNS, TCP, TLS, HTTP, QUIC, and DNSSEC.

Prefer navigating by interest instead of lab number? See [`LEARNING_PATHS.md`](LEARNING_PATHS.md) for genre groupings and goal-based routes (home network / web engineer / datacenter). 日本語: 番号順でなくジャンル・目的で選びたい場合は [`LEARNING_PATHS.md`](LEARNING_PATHS.md) へ。

By the end of the sequence, you should be able to read a focused part of an RFC, run a small experiment, inspect logs or packets, and explain what happened using protocol terms.

日本語: このロードマップは、Protocol Lab の流れを示します。BGP/RPKI から始めて、DNS、TCP、TLS、HTTP、QUIC、DNSSEC へ進みます。最後には、RFC の必要な部分を読み、小さな実験を動かし、ログやパケットを見て、起きたことをプロトコル用語で説明できる状態を目指します。

## How To Use This Roadmap

Each lab follows the same basic rhythm:

1. Read a small RFC slice.
2. Run a minimal hands-on experiment.
3. Observe command output, logs, or packets.
4. Explain the result in your own words.

日本語: 各Labは「RFCを少し読む、最小実験を動かす、出力・ログ・パケットを観察する、自分の言葉で説明する」という流れで進みます。

## Learning Outcomes

After completing the labs, you should be able to:

- Explain a BGP route announcement from ASNs, prefixes, NLRI, AS_PATH, NEXT_HOP, and ORIGIN.
- Recognize how UPDATE messages announce and withdraw routes.
- Describe why competing origins and route leaks are operationally risky.
- Read ROA and RPKI origin validation results.
- Trace DNS recursive resolution and caching behavior.
- Interpret TCP handshakes, teardown, retransmission, and windowing from packet traces.
- Identify the visible parts of TLS handshakes, certificates, SNI, and ALPN.
- Follow an HTTP request across DNS, transport, TLS, and application layers.
- Compare HTTP/2 streams with QUIC-based transport behavior at a high level.
- Explain how DNSSEC proves a DNS answer is genuine, and why a tampered answer is rejected.

日本語:

- ASN、prefix、NLRI、AS_PATH、NEXT_HOP、ORIGIN から BGP の経路広告を説明できる。
- UPDATE message が経路の広告と取り下げをどう表すかを読める。
- competing origin や route leak がなぜ危険なのかを説明できる。
- ROA と RPKI origin validation の結果を読める。
- DNS の再帰問い合わせと cache の挙動を追える。
- TCP の handshake、切断、再送、windowing を packet trace から読める。
- TLS handshake、certificate、SNI、ALPN の観察できる部分を見分けられる。
- DNS、transport、TLS、HTTP をまたいで1つのWeb requestを追える。
- HTTP/2 の stream と QUIC transport の違いを大まかに説明できる。
- DNSSEC が DNS の答えの真正性をどう証明するか、改ざんがなぜ拒否されるかを説明できる。

## Lab Sequence

| Lab | Topic | You will learn | You will observe | Output |
|---|---|---|---|---|
| 01 | [BGP: ASNs, Prefixes, and Route Announcements](labs/bgp-01-as-prefix-announcement.md) | ASNs, prefixes, NLRI, AS_PATH, NEXT_HOP, ORIGIN | One route in FRRouting and a packet capture | Explain one prefix announcement from RFC terms |
| 02 | [BGP: UPDATE, NEXT_HOP, and Withdrawal](labs/bgp-02-update-nexthop-withdrawal.md) | UPDATE message structure, path attributes, withdrawn routes | Announce and withdraw packets | Explain how a route appears and disappears |
| 03 | [BGP: Competing Origins and Route Leaks](labs/bgp-03-competing-origins-route-leaks.md) | Why the same prefix from different origins is risky | Two origins for one prefix and their paths | Compare paths and identify the risk |
| 04 | [RPKI: ROAs and Origin Validation](labs/rpki-04-roa-origin-validation.md) | ROA, origin AS, max length, valid, invalid, not found | Origin validation results | Explain why a route is valid, invalid, or not found |
| 05 | [DNS: Recursive Resolution with `dig`](labs/dns-05-recursive-resolution.md) | Stub resolver, recursive resolver, root, TLD, authoritative server | Iterative lookup flow | Draw the resolution path for one name |
| 06 | [DNS: Caching, TTL, and Negative Answers](labs/dns-06-caching-ttl-negative.md) | TTL, cache behavior, NXDOMAIN, SOA in negative caching | Repeated queries and cached responses | Explain why an answer changed or did not change |
| 07 | [TCP: Handshake, Sequence Numbers, and Teardown](labs/tcp-07-handshake-teardown.md) | SYN, SYN-ACK, ACK, sequence numbers, FIN, RST | tcpdump or Wireshark traces | Annotate one connection lifecycle |
| 08 | [TCP: Retransmission, Windowing, and Loss](labs/tcp-08-retransmission-windowing-loss.md) | Retransmission, RTT, receive window, simple packet loss | Timing, loss, and recovery | Explain how TCP recovers from loss |
| 09 | [TLS: Handshake, Certificates, and Keys](labs/tls-09-handshake-certificates.md) | ClientHello, ServerHello, certificate chain, SNI, ALPN | TLS handshake metadata | Identify what is visible before encryption takes over |
| 10 | [HTTP: Requests, Responses, and Caching](labs/http-10-requests-responses-caching.md) | Methods, headers, status codes, cache headers | `curl -v`, logs, and packet output | Explain one HTTP exchange |
| 11 | [HTTP/2 and QUIC: Streams and Multiplexing](labs/quic-11-http2-quic-streams.md) | Frames, streams, multiplexing, HTTP/2 vs QUIC transport differences | Negotiated protocol and stream behavior | Compare stream behavior across transports |
| 12 | [End-to-End: From Domain Name to Encrypted Web Request](labs/e2e-12-end-to-end.md) | DNS, TCP or QUIC, TLS, and HTTP together | One complete request path | Explain each layer in order |
| 13 | [DNSSEC: Signatures, Trust Anchors, and the AD Flag](labs/dns-13-dnssec-validation.md) | RRSIG, DNSKEY (KSK/ZSK), trust anchor, AD and CD flags | A validated answer and a rejected (tampered) one | Explain how a resolver proves an answer is genuine |
| 14 | [Encrypted DNS: DoT and DoH](labs/dns-14-encrypted-dns-dot-doh.md) | Do53 vs DoT (853) vs DoH (443), what an on-path observer can read | The query name in cleartext vs inside TLS | Explain what encrypted DNS hides and what it does not |
| 15 | [Mutual TLS: Proving the Client Too](labs/tls-15-mutual-tls.md) | Client certificates, CertificateRequest, a private CA, -Verify | An authenticated handshake vs a certless client rejected | Explain how both ends prove identity in mTLS |
| 16 | [WireGuard: An Encrypted Tunnel You Can See Into](labs/wg-16-wireguard-tunnel.md) | WireGuard keys/peers, the underlay vs the tunnel, UDP encapsulation | A ping as encrypted UDP on the underlay, cleartext ICMP inside wg0 | Explain what a tunnel encrypts and what stays visible |
| 17 | [DANE: When DNS Vouches for the Certificate](labs/dane-17-dane-tlsa.md) | TLSA records, DANE-EE, DNSSEC-signed cert pinning, no CA needed | A signed TLSA matching a cert, and an impostor rejected | Explain how DNSSEC + TLSA can authenticate a cert without a CA |
| 18 | [VXLAN: An Overlay You Can Read on the Wire](labs/vxlan-18-l2-overlay.md) | VXLAN encapsulation, VNI, UDP 4789, overlay vs underlay, L2-over-L3 | A ping as VXLAN over UDP with the inner frame in the clear | Contrast an unencrypted overlay with an encrypted tunnel |
| 19 | [traceroute and TTL: Mapping a Path Hop by Hop](labs/trace-19-traceroute-ttl.md) | IP TTL, ICMP time-exceeded, how routers reveal a path | traceroute hops and the time-exceeded replies that build them | Explain how traceroute maps a network path |
| 20 | [NAT: One Public Address for Many](labs/nat-20-source-translation.md) | Source NAT (masquerade), private vs public addresses, connection tracking | The server seeing the NAT public address, and the conntrack mapping | Explain how NAT hides private addresses behind one public IP |
| 21 | [GRE: An Unencrypted Layer-3 Tunnel](labs/gre-21-l3-tunnel.md) | GRE encapsulation (IP proto 47), L3 tunnels, encapsulation vs encryption | A ping as GRE on the underlay with the inner IP in the clear | Place GRE among WireGuard and VXLAN on the encrypt/encapsulate axes |
| 22 | [DHCP: Four Messages for an Address](labs/dhcp-22-dora.md) | DHCP DORA (Discover/Offer/Request/Ack), leases, broadcast | An address-less client obtaining a lease, captured on the wire | Explain how a host gets an address with no prior configuration |
| 23 | [IPv6 Neighbor Discovery: ARP's Successor](labs/ndp-23-neighbor-discovery.md) | ICMPv6 NS/NA, solicited-node multicast, the neighbor cache | A Neighbor Solicitation and Advertisement resolving a neighbor | Explain how IPv6 finds a neighbor MAC without broadcast |
| 24 | [ARP: The IPv4 Original](labs/arp-24-address-resolution.md) | ARP request/reply, broadcast resolution, the ARP cache | A broadcast ARP request and unicast reply resolving a MAC | Contrast ARP (broadcast) with NDP (multicast) |
| 25 | [MTU and Path MTU Discovery](labs/mtu-25-path-mtu-discovery.md) | MTU, the DF bit, ICMP fragmentation-needed, cached path MTU | An oversized DF packet rejected with the next-hop MTU | Explain how a sender learns the largest packet a path allows |
| 26 | [VLANs: Two Networks on One Wire](labs/vlan-26-8021q.md) | 802.1Q tags, VLAN IDs, trunk links, broadcast-domain isolation | Tagged frames (vlan 100 / 200) sharing one link yet kept apart | Explain how one physical link carries isolated virtual LANs |
| 27 | [HTTP Redirects and Cookies](labs/http-27-redirects-cookies.md) | 3xx redirects + Location, Set-Cookie / Cookie, statelessness | A 302 followed to a new URL, and a cookie stored and resent | Explain how HTTP steers a client and remembers it across requests |
| 28 | [QoS: Shaping a Link with a Token Bucket](labs/qos-28-traffic-shaping.md) | Traffic shaping, tc, token bucket (tbf), rate limiting | iperf3 throughput dropping to the configured rate under a shaper | Explain how a token-bucket qdisc caps a link's throughput |
| 29 | [Multicast and IGMP: One Sender, Many Receivers](labs/mcast-29-igmp.md) | IP multicast, group addresses, IGMP membership, multicast MAC, one copy per segment | Two receivers joining a group via IGMP and both getting one UDP stream | Explain how one send reaches many receivers without a per-receiver copy |
| 30 | [TCP Congestion Control: CUBIC vs BBR](labs/cc-30-congestion-control.md) | Congestion window, loss-based (CUBIC) vs model-based (BBR), random loss, ss -ti | The same lossy path giving ~12 Mbit/s under CUBIC and ~88 Mbit/s under BBR | Explain why the congestion-control choice, not the link, sets throughput on a lossy path |
| 31 | [Anycast: One Address, Many Servers](labs/anycast-31-bgp.md) | Anycast, one prefix announced from many places, BGP best-path, failover | Two servers announcing one VIP; routing picks server-a, then fails over to server-b | Explain how one address is served by many instances and fails over via routing |
| 32 | [ECMP: Two Equal Paths, Hashed per Flow](labs/ecmp-32-multipath.md) | Equal-cost multipath, BGP maximum-paths, per-flow hashing, L3 vs L4 hash policy | Parallel TCP flows splitting ~evenly across two links (and piling onto one under L3 hashing) | Explain how equal-cost paths share load per flow and why the hash policy matters |
| 33 | [L4 Load Balancing: One VIP, a Pool of Servers](labs/lb-33-ipvs.md) | Virtual IP, IPVS director, round-robin scheduler, NAT mode, stateful conn table | 30 connections to one VIP spread 10/10/10 across three backends | Explain how an L4 load balancer distributes connections across a backend pool |
| 34 | [OSPF: Flood the Map, Compute the Shortest Path](labs/ospf-34-link-state.md) | Link-state IGP, Hello/adjacency, LSA/LSDB, SPF (Dijkstra), cost, reconvergence | Full adjacencies, an SPF route by cost, and reconvergence when the direct link fails | Explain how a link-state IGP builds one map and computes shortest paths by cost |
| 35 | [BFD: Catching a Silent Failure in Under a Second](labs/bfd-35-fast-failure-detection.md) | BFD, sub-second detection timers, silent (link-up) failure, OSPF integration | A silent forwarding failure caught in ~900 ms vs OSPF's 40 s dead timer | Explain how BFD detects forwarding failure fast and drives routing reconvergence |
| 36 | [Stateful Firewall: Decide by the Connection](labs/fw-36-stateful-firewall.md) | conntrack, ctstate NEW/ESTABLISHED/RELATED, default-drop, allow-return-by-state | An outbound-initiated connection allowed but an unsolicited inbound one dropped | Explain how a stateful firewall permits replies by connection state, not per-packet rules |
| 37 | [TCP MSS Clamping: Fitting Segments to the Narrowest Link](labs/mss-37-clamping.md) | TCP MSS option, MTU vs MSS, PMTUD blackhole, TCPMSS --clamp-mss-to-pmtu | A router rewriting the SYN's MSS from 1460 to 1360 to fit a 1400-MTU link | Explain how a router clamps the SYN MSS so segments fit the path's smallest link |
| 38 | [Policy Routing: Choosing the Path by Source](labs/pbr-38-policy-routing.md) | Multiple routing tables, ip rule, source-based selection, multi-homing | The same destination routed over different uplinks depending on the source host | Explain how a rule database selects a routing table by source, not just destination |
| 39 | [Reverse Path Filtering: Dropping Spoofed Sources](labs/rpf-39-reverse-path-filtering.md) | Ingress filtering (BCP 38), rp_filter strict/loose, reverse route lookup, anti-spoofing | A spoofed source dropped at ingress while the real source still passes | Explain how reverse path filtering validates a packet's source against its arrival interface |
| 40 | [DNAT: Publishing a Service with Port Forwarding](labs/dnat-40-port-forwarding.md) | Destination NAT, PREROUTING, port forwarding, conntrack un-NAT, SNAT contrast | An external client reaching a private internal server through a public address:port | Explain how DNAT publishes an inside service and how it complements source NAT |
| 41 | [DNS Round-Robin: Spreading Clients at the Naming Layer](labs/dnsrr-41-round-robin.md) | Multiple A records (RRset), rrset-order cyclic, TTL/caching, load-spread trade-offs | One name's three A records rotated per response so lookups spread across them | Explain how DNS round-robin spreads clients and why it is coarse compared to a real balancer |
| 42 | [Split-Horizon DNS: One Name, Different Answers by Who Asks](labs/dns-views-42-split-horizon.md) | BIND views, match-clients by source, split-brain, internal vs public answers | The same name resolving to a private or public address depending on the client | Explain how views serve different answers per source and where split-horizon is used |

日本語:

| Lab | トピック | 学ぶこと | 観察するもの | 到達点 |
|---|---|---|---|---|
| 01 | [BGP: ASN、prefix、経路広告](labs/bgp-01-as-prefix-announcement.md) | ASN、prefix、NLRI、AS_PATH、NEXT_HOP、ORIGIN | FRRouting 上の1本の経路と packet capture | 1つの prefix announcement を RFC の言葉で説明する |
| 02 | [BGP: UPDATE、NEXT_HOP、withdrawal](labs/bgp-02-update-nexthop-withdrawal.md) | UPDATE message の構造、path attribute、withdrawn route | 経路広告と取り下げのパケット | 経路が現れて消える仕組みを説明する |
| 03 | [BGP: competing origin と route leak](labs/bgp-03-competing-origins-route-leaks.md) | 同じ prefix が異なる origin から見える危険性 | 1つの prefix に対する2つの origin と path | path を比較してリスクを説明する |
| 04 | [RPKI: ROA と origin validation](labs/rpki-04-roa-origin-validation.md) | ROA、origin AS、max length、valid、invalid、not found | origin validation の結果 | 経路が valid / invalid / not found になる理由を説明する |
| 05 | [DNS: `dig` で見る再帰問い合わせ](labs/dns-05-recursive-resolution.md) | stub resolver、recursive resolver、root、TLD、authoritative server | iterative lookup の流れ | 1つの名前解決経路を図にできる |
| 06 | [DNS: cache、TTL、negative answer](labs/dns-06-caching-ttl-negative.md) | TTL、cache、NXDOMAIN、negative caching の SOA | 繰り返し query と cached response | answer が変わる理由、変わらない理由を説明する |
| 07 | [TCP: handshake、sequence number、teardown](labs/tcp-07-handshake-teardown.md) | SYN、SYN-ACK、ACK、sequence number、FIN、RST | tcpdump または Wireshark の trace | 1つの connection lifecycle を注釈できる |
| 08 | [TCP: retransmission、windowing、loss](labs/tcp-08-retransmission-windowing-loss.md) | 再送、RTT、receive window、単純な packet loss | timing、loss、recovery | TCP が loss から回復する流れを説明する |
| 09 | [TLS: handshake、certificate、key](labs/tls-09-handshake-certificates.md) | ClientHello、ServerHello、certificate chain、SNI、ALPN | TLS handshake metadata | 暗号化前に見える情報を識別する |
| 10 | [HTTP: request、response、cache](labs/http-10-requests-responses-caching.md) | method、header、status code、cache header | `curl -v`、ログ、packet output | 1つの HTTP exchange を説明する |
| 11 | [HTTP/2 and QUIC: stream と multiplexing](labs/quic-11-http2-quic-streams.md) | frame、stream、multiplexing、HTTP/2 と QUIC transport の違い | negotiated protocol と stream behavior | transport ごとの stream behavior を比較する |
| 12 | [End-to-End: domain name から encrypted web request まで](labs/e2e-12-end-to-end.md) | DNS、TCP または QUIC、TLS、HTTP のつながり | 1つの complete request path | 各 layer の役割を順に説明する |
| 13 | [DNSSEC: 署名、trust anchor、AD フラグ](labs/dns-13-dnssec-validation.md) | RRSIG、DNSKEY(KSK/ZSK)、trust anchor、AD と CD フラグ | 検証済みの答えと、拒否された改ざん答え | resolver が答えの真正性をどう証明するか説明する |
| 14 | [暗号化DNS: DoT と DoH](labs/dns-14-encrypted-dns-dot-doh.md) | Do53 vs DoT (853) vs DoH (443)、経路上の観測者に何が見えるか | query 名が平文 vs TLS の中 | 暗号化DNS が何を隠し何を隠さないかを説明する |
| 15 | [Mutual TLS: client も証明する](labs/tls-15-mutual-tls.md) | client 証明書、CertificateRequest、専用CA、-Verify | 認証済み handshake vs 証明書なし client の拒否 | mTLS で両端がどう身元を証明するか説明する |
| 16 | [WireGuard: 中が見える暗号トンネル](labs/wg-16-wireguard-tunnel.md) | WireGuard の鍵/peer、underlay と tunnel、UDP encapsulation | underlay では暗号化UDP、wg0 内では平文ICMP の ping | tunnel が何を暗号化し何が見えたままかを説明する |
| 17 | [DANE: DNS が証明書を保証する](labs/dane-17-dane-tlsa.md) | TLSA レコード、DANE-EE、DNSSEC 署名による cert pin、CA 不要 | 署名済み TLSA と一致する cert、拒否される impostor | DNSSEC + TLSA で CA 無しに cert を認証する仕組みを説明する |
| 18 | [VXLAN: 中身が見えるオーバーレイ](labs/vxlan-18-l2-overlay.md) | VXLAN encapsulation、VNI、UDP 4789、overlay と underlay、L2-over-L3 | VXLAN over UDP で運ばれ、内側フレームが平文で見える ping | 暗号化なしの overlay と暗号トンネルを対比する |
| 19 | [traceroute と TTL: 経路を hop ごとに映す](labs/trace-19-traceroute-ttl.md) | IP TTL、ICMP time-exceeded、ルータが経路を明かす仕組み | traceroute の hop と、それを作る time-exceeded 応答 | traceroute が経路をどう地図化するか説明する |
| 20 | [NAT: 多数を1つの public アドレスに](labs/nat-20-source-translation.md) | source NAT (masquerade)、private と public アドレス、connection tracking | server が見る NAT の public アドレスと、conntrack の変換 | NAT が private アドレスを1つの public IP の裏に隠す仕組みを説明する |
| 21 | [GRE: 暗号化しない L3 トンネル](labs/gre-21-l3-tunnel.md) | GRE encapsulation (IP proto 47)、L3 tunnel、encapsulation と encryption の別 | underlay で GRE として運ばれ、内側 IP が平文で見える ping | GRE を WireGuard・VXLAN と暗号化/カプセル化の軸で位置づける |
| 22 | [DHCP: アドレスを得る4つのメッセージ](labs/dhcp-22-dora.md) | DHCP DORA (Discover/Offer/Request/Ack)、lease、broadcast | アドレスなしの client が lease を得る様子の capture | 設定なしでホストがアドレスを得る仕組みを説明する |
| 23 | [IPv6 近隣探索: ARP の後継](labs/ndp-23-neighbor-discovery.md) | ICMPv6 NS/NA、solicited-node multicast、neighbor cache | 近隣を解決する Neighbor Solicitation と Advertisement | IPv6 が broadcast なしで近隣の MAC を見つける仕組みを説明する |
| 24 | [ARP: IPv4 の原型](labs/arp-24-address-resolution.md) | ARP request/reply、broadcast による解決、ARP cache | MAC を解決する broadcast ARP request と unicast reply | ARP(broadcast)と NDP(multicast)を対比する |
| 25 | [MTU と Path MTU Discovery](labs/mtu-25-path-mtu-discovery.md) | MTU、DF ビット、ICMP fragmentation-needed、cache された path MTU | DF 付きの大きすぎるパケットが next-hop MTU 付きで拒否される様子 | 経路が許す最大パケットサイズを送信側がどう学ぶか説明する |
| 26 | [VLAN: 1本の線に2つのネットワーク](labs/vlan-26-8021q.md) | 802.1Q tag、VLAN ID、trunk、broadcast domain の分離 | 1本のリンクを共有しつつ分離される tagged frame(vlan 100/200) | 1本の物理リンクが分離された仮想 LAN をどう運ぶか説明する |
| 27 | [HTTP redirect と cookie](labs/http-27-redirects-cookies.md) | 3xx redirect と Location、Set-Cookie / Cookie、statelessness | /new へ追従される 302 と、保存・再送される cookie | HTTP が client をどう誘導し、リクエストをまたいで覚えるか説明する |
| 28 | [QoS: token bucket でリンクを絞る](labs/qos-28-traffic-shaping.md) | traffic shaping、tc、token bucket (tbf)、rate 制限 | shaper で iperf3 の throughput が設定 rate に落ちる様子 | token-bucket qdisc がリンクの throughput をどう制限するか説明する |
| 29 | [Multicast と IGMP: 1つの送信を多数へ](labs/mcast-29-igmp.md) | IP multicast、group address、IGMP membership、multicast MAC、セグメントに1コピー | IGMP で group に join した2つの receiver が同じ1本の UDP stream を受け取る様子 | 1回の送信が receiver ごとのコピー無しに多数へ届く仕組みを説明する |
| 30 | [TCP 輻輳制御: CUBIC vs BBR](labs/cc-30-congestion-control.md) | congestion window、loss-based (CUBIC) と model-based (BBR)、ランダム loss、ss -ti | 同じ lossy path で CUBIC は約12 Mbit/s、BBR は約88 Mbit/s になる様子 | lossy path では link ではなく輻輳制御の選択が throughput を決めることを説明する |
| 31 | [Anycast: 1つのアドレスを多数のサーバで](labs/anycast-31-bgp.md) | anycast、同一 prefix を複数から announce、BGP best-path、フェイルオーバー | 2台が同じ VIP を announce し、routing が server-a を選び、障害で server-b へ切り替わる様子 | 1つのアドレスが多数のインスタンスで提供され routing でフェイルオーバーする仕組みを説明する |
| 32 | [ECMP: 2つの等コスト経路を flow ごとに hash](labs/ecmp-32-multipath.md) | equal-cost multipath、BGP maximum-paths、per-flow hashing、L3 vs L4 hash policy | 並行 TCP flow が2リンクにほぼ均等に分かれる様子(L3 hashing だと片方に集中) | 等コスト経路が flow 単位で負荷分散する仕組みと hash policy の重要性を説明する |
| 33 | [L4 ロードバランシング: 1つの VIP と複数の backend](labs/lb-33-ipvs.md) | 仮想 IP、IPVS director、round-robin scheduler、NAT モード、ステートフルな接続テーブル | 1つの VIP への30接続が3 backend に 10/10/10 で分配される様子 | L4 ロードバランサが接続を backend プールへどう分配するか説明する |
| 34 | [OSPF: 地図を配って最短経路を計算する](labs/ospf-34-link-state.md) | link-state IGP、Hello/隣接、LSA/LSDB、SPF(Dijkstra)、cost、再収束 | Full 隣接、cost 最短の SPF 経路、直リンク障害での再収束 | link-state IGP が同一の地図を作り cost 最短経路を計算する仕組みを説明する |
| 35 | [BFD: silent failure を1秒未満で検出](labs/bfd-35-fast-failure-detection.md) | BFD、サブ秒の検出タイマ、silent(リンク up)障害、OSPF との結合 | silent な転送障害を約900msで検出(OSPF 単独の40秒 dead に対し) | BFD が転送障害を高速検出し routing の再収束を駆動する仕組みを説明する |
| 36 | [ステートフルファイアウォール: 接続で判断する](labs/fw-36-stateful-firewall.md) | conntrack、ctstate NEW/ESTABLISHED/RELATED、default-drop、戻りを状態で許可 | 内側発の接続は通り、外側発の勝手な新規は落ちる様子 | ステートフルファイアウォールが応答を接続状態で許可する仕組みを説明する |
| 37 | [TCP MSS clamping: segment を最小リンクに合わせる](labs/mss-37-clamping.md) | TCP MSS option、MTU と MSS、PMTUD blackhole、TCPMSS --clamp-mss-to-pmtu | ルータが SYN の MSS を 1460→1360 に書き換え 1400-MTU リンクに合わせる様子 | ルータが SYN の MSS を clamp し segment を path 最小リンクに収める仕組みを説明する |
| 38 | [ポリシールーティング: 送信元で経路を選ぶ](labs/pbr-38-policy-routing.md) | 複数ルーティングテーブル、ip rule、source ベース選択、マルチホーミング | 同じ宛先が送信元ホストによって別のアップリンクを通る様子 | rule データベースが送信元でテーブルを選ぶ(宛先だけでない)仕組みを説明する |
| 39 | [Reverse path filtering: 詐称された送信元を落とす](labs/rpf-39-reverse-path-filtering.md) | ingress filtering (BCP 38)、rp_filter strict/loose、送信元逆引き、anti-spoofing | 詐称された送信元は入口で落ち、本物の送信元は通る様子 | reverse path filtering が送信元を到着インターフェースと照合して検証する仕組みを説明する |
| 40 | [DNAT: ポートフォワードでサービスを公開する](labs/dnat-40-port-forwarding.md) | destination NAT、PREROUTING、ポートフォワード、conntrack un-NAT、SNAT との対比 | 外部クライアントが公開アドレス:ポート経由で内部の private サーバに届く様子 | DNAT が内側サービスを公開し source NAT と対をなす仕組みを説明する |
| 41 | [DNS ラウンドロビン: 名前解決の層でクライアントを散らす](labs/dnsrr-41-round-robin.md) | 複数 A レコード(RRset)、rrset-order cyclic、TTL/caching、分散のトレードオフ | 1名前の3つの A レコードが応答ごとに回転し解決が分散する様子 | DNS ラウンドロビンがクライアントを散らす仕組みと実 LB より粗い理由を説明する |
| 42 | [Split-horizon DNS: 同じ名前を相手で別の答えに](labs/dns-views-42-split-horizon.md) | BIND views、match-clients(送信元)、split-brain、内部 vs 公開の答え | 同じ名前がクライアントによって private / public に解決する様子 | views が送信元ごとに別の答えを返す仕組みと split-horizon の用途を説明する |

## Planned — Batch 4: Cloud & Modern Infrastructure (43–46, draft, not yet authored)

Agreed direction (2026-07-11): after finishing the first 42 labs (protocol fundamentals through
operational hardening), the next batch pivots from "read the wire" to "read the platform" —
container and cloud networking, where the same fundamentals (routing, NAT, mTLS) reappear one
layer up. Target cadence: 2–3 new labs authored per week, each flowing through the existing
JA/EN conversion + drip-publish pipeline once written. No lab content exists yet for 43–46 —
this section is a scope agreement, not a commitment to specific lab text.

| Lab | Working title | You will learn | You will observe |
|---|---|---|---|
| 43 | Kubernetes Networking: kube-proxy, Services, and CNI Basics | Pod network namespaces, ClusterIP/NodePort, iptables vs IPVS mode, a minimal CNI | A Service load-balancing to pods across nodes, and what changes between kube-proxy modes |
| 44 | Service Mesh mTLS: Sidecar Proxies Without Touching App Code | Sidecar injection, mTLS between two pods, mesh-managed certificate rotation | Plaintext app traffic on localhost vs encrypted mTLS on the wire between pods |
| 45 | Cloud VPC Peering and Route Tables | VPC peering, route table propagation, why peering is non-transitive | Two peered VPCs reaching each other, and a third VPC that can't reach through the peer |
| 46 | eBPF Packet Observability: Tracing a Connection Without tcpdump | eBPF hooks (socket/skb), bpftrace-style tracing, why eBPF avoids full packet capture overhead | A live connection traced through kernel hooks instead of a pcap file |

日本語:

次のバッチの方向性(2026-07-11合意): 最初の42本(プロトコル基礎〜運用の堅牢化)が一巡したので、次は
「線を読む」から「プラットフォームを読む」へ視点を移す — コンテナ/クラウドのネットワーキングで、
同じ基礎(ルーティング、NAT、mTLS)が1つ上のレイヤーで再登場する構成。ペース目標: 週2〜3本を執筆し、
書けたものから順に既存のJA/EN変換+ドリップ公開パイプラインに乗せる。43〜46はまだ本文未執筆 —
このセクションは範囲の合意であり、Labの本文を確定するものではない。

| Lab | 仮タイトル | 学ぶこと | 観察するもの |
|---|---|---|---|
| 43 | Kubernetes ネットワーキング: kube-proxy・Service・CNI入門 | Pod のネットワーク namespace、ClusterIP/NodePort、iptables vs IPVS モード、最小 CNI | Service が複数ノードの Pod へロードバランスする様子、kube-proxy モードによる違い |
| 44 | サービスメッシュ mTLS: アプリコードを変えずに sidecar で暗号化 | sidecar injection、Pod 間 mTLS、mesh が管理する証明書ローテーション | localhost 上は平文のアプリ通信が、Pod 間の実配線では mTLS で暗号化される様子 |
| 45 | クラウド VPC ピアリングとルートテーブル | VPC peering、route table の伝播、peering が非推移的である理由 | ピア接続された2つのVPCが到達し合う様子と、peer 経由では届かない第3のVPC |
| 46 | eBPF によるパケット可観測性: tcpdump を使わずに接続を追う | eBPF フック(socket/skb)、bpftrace 的トレース、eBPF がフルパケットキャプチャのオーバーヘッドを避ける理由 | pcap ファイルではなく kernel hook 経由でライブの接続を追跡する様子 |

## Current Entry Point

Start with [BGP Lab 01: One Prefix Announcement You Can Explain](labs/bgp-01-as-prefix-announcement.md). It is the first complete lab in the sequence and introduces the read-run-observe style used throughout Protocol Lab.

日本語: 最初は [BGP Lab 01: One Prefix Announcement You Can Explain](labs/bgp-01-as-prefix-announcement.md) から始めてください。このLabで、Protocol Lab 全体で使う「読む、動かす、観察する」の進め方を体験できます。

## After Protocol Lab: The Intermediate Course

When you finish the labs (or whenever a protocol makes you want to see its decision
logic, not just its packets), the sibling course **Protocol in Code**
(https://github.com/pathvector-studio/protocol-in-code) reads the same protocols as
small Python programs — 23 tracks / 151 sessions. Its
[`LEARNING_PATHS.md`](https://github.com/pathvector-studio/protocol-in-code/blob/main/LEARNING_PATHS.md)
has a lab-by-lab cross-reference table ("you ran BGP in Lab 01–03 → read it as code in
the bgp track") plus goal-based roadmaps.

日本語: Labを終えたら（あるいは動かしたプロトコルの「判断の中身」が気になったら）、
姉妹コース **Protocol in Code** へ。同じプロトコルを小さなPythonプログラムとして読む
中級コースで、`LEARNING_PATHS.md` にLab対応表と目的別ロードマップがあります。
