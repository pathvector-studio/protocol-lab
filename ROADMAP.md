# Protocol Lab Roadmap

This roadmap shows the labs in Protocol Lab. The sequence starts with BGP and RPKI, then expands into DNS, TCP, TLS, HTTP, QUIC, and DNSSEC.

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

## Current Entry Point

Start with [BGP Lab 01: One Prefix Announcement You Can Explain](labs/bgp-01-as-prefix-announcement.md). It is the first complete lab in the sequence and introduces the read-run-observe style used throughout Protocol Lab.

日本語: 最初は [BGP Lab 01: One Prefix Announcement You Can Explain](labs/bgp-01-as-prefix-announcement.md) から始めてください。このLabで、Protocol Lab 全体で使う「読む、動かす、観察する」の進め方を体験できます。
