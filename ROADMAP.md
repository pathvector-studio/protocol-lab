# Protocol Lab Roadmap

This roadmap shows the first twelve labs in Protocol Lab. The sequence starts with BGP and RPKI, then expands into DNS, TCP, TLS, HTTP, and QUIC.

By the end of the sequence, you should be able to read a focused part of an RFC, run a small experiment, inspect logs or packets, and explain what happened using protocol terms.

日本語: このロードマップは、Protocol Lab の最初の12回の流れを示します。BGP/RPKI から始めて、DNS、TCP、TLS、HTTP、QUIC へ進みます。最後には、RFC の必要な部分を読み、小さな実験を動かし、ログやパケットを見て、起きたことをプロトコル用語で説明できる状態を目指します。

## How To Use This Roadmap

Each lab follows the same basic rhythm:

1. Read a small RFC slice.
2. Run a minimal hands-on experiment.
3. Observe command output, logs, or packets.
4. Explain the result in your own words.

日本語: 各Labは「RFCを少し読む、最小実験を動かす、出力・ログ・パケットを観察する、自分の言葉で説明する」という流れで進みます。

## Learning Outcomes

After completing the twelve labs, you should be able to:

- Explain a BGP route announcement from ASNs, prefixes, NLRI, AS_PATH, NEXT_HOP, and ORIGIN.
- Recognize how UPDATE messages announce and withdraw routes.
- Describe why competing origins and route leaks are operationally risky.
- Read ROA and RPKI origin validation results.
- Trace DNS recursive resolution and caching behavior.
- Interpret TCP handshakes, teardown, retransmission, and windowing from packet traces.
- Identify the visible parts of TLS handshakes, certificates, SNI, and ALPN.
- Follow an HTTP request across DNS, transport, TLS, and application layers.
- Compare HTTP/2 streams with QUIC-based transport behavior at a high level.

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

## Twelve-Lab Sequence

| Lab | Topic | You will learn | You will observe | Output |
|---|---|---|---|---|
| 01 | [BGP: ASNs, Prefixes, and Route Announcements](labs/bgp-01-as-prefix-announcement.md) | ASNs, prefixes, NLRI, AS_PATH, NEXT_HOP, ORIGIN | One route in FRRouting and a packet capture | Explain one prefix announcement from RFC terms |
| 02 | [BGP: UPDATE, NEXT_HOP, and Withdrawal](labs/bgp-02-update-nexthop-withdrawal.md) | UPDATE message structure, path attributes, withdrawn routes | Announce and withdraw packets | Explain how a route appears and disappears |
| 03 | BGP: Competing Origins and Route Leaks | Why the same prefix from different origins is risky | Two origins for one prefix and their paths | Compare paths and identify the risk |
| 04 | RPKI: ROAs and Origin Validation | ROA, origin AS, max length, valid, invalid, not found | Origin validation results | Explain why a route is valid, invalid, or not found |
| 05 | DNS: Recursive Resolution with `dig` | Stub resolver, recursive resolver, root, TLD, authoritative server | Iterative lookup flow | Draw the resolution path for one name |
| 06 | DNS: Caching, TTL, and Negative Answers | TTL, cache behavior, NXDOMAIN, SOA in negative caching | Repeated queries and cached responses | Explain why an answer changed or did not change |
| 07 | TCP: Handshake, Sequence Numbers, and Teardown | SYN, SYN-ACK, ACK, sequence numbers, FIN, RST | tcpdump or Wireshark traces | Annotate one connection lifecycle |
| 08 | TCP: Retransmission, Windowing, and Loss | Retransmission, RTT, receive window, simple packet loss | Timing, loss, and recovery | Explain how TCP recovers from loss |
| 09 | TLS: Handshake, Certificates, and Keys | ClientHello, ServerHello, certificate chain, SNI, ALPN | TLS handshake metadata | Identify what is visible before encryption takes over |
| 10 | HTTP: Requests, Responses, and Caching | Methods, headers, status codes, cache headers | `curl -v`, logs, and packet output | Explain one HTTP exchange |
| 11 | HTTP/2 and QUIC: Streams and Multiplexing | Frames, streams, multiplexing, HTTP/2 vs QUIC transport differences | Negotiated protocol and stream behavior | Compare stream behavior across transports |
| 12 | End-to-End: From Domain Name to Encrypted Web Request | DNS, TCP or QUIC, TLS, and HTTP together | One complete request path | Explain each layer in order |

日本語:

| Lab | トピック | 学ぶこと | 観察するもの | 到達点 |
|---|---|---|---|---|
| 01 | [BGP: ASN、prefix、経路広告](labs/bgp-01-as-prefix-announcement.md) | ASN、prefix、NLRI、AS_PATH、NEXT_HOP、ORIGIN | FRRouting 上の1本の経路と packet capture | 1つの prefix announcement を RFC の言葉で説明する |
| 02 | [BGP: UPDATE、NEXT_HOP、withdrawal](labs/bgp-02-update-nexthop-withdrawal.md) | UPDATE message の構造、path attribute、withdrawn route | 経路広告と取り下げのパケット | 経路が現れて消える仕組みを説明する |
| 03 | BGP: competing origin と route leak | 同じ prefix が異なる origin から見える危険性 | 1つの prefix に対する2つの origin と path | path を比較してリスクを説明する |
| 04 | RPKI: ROA と origin validation | ROA、origin AS、max length、valid、invalid、not found | origin validation の結果 | 経路が valid / invalid / not found になる理由を説明する |
| 05 | DNS: `dig` で見る再帰問い合わせ | stub resolver、recursive resolver、root、TLD、authoritative server | iterative lookup の流れ | 1つの名前解決経路を図にできる |
| 06 | DNS: cache、TTL、negative answer | TTL、cache、NXDOMAIN、negative caching の SOA | 繰り返し query と cached response | answer が変わる理由、変わらない理由を説明する |
| 07 | TCP: handshake、sequence number、teardown | SYN、SYN-ACK、ACK、sequence number、FIN、RST | tcpdump または Wireshark の trace | 1つの connection lifecycle を注釈できる |
| 08 | TCP: retransmission、windowing、loss | 再送、RTT、receive window、単純な packet loss | timing、loss、recovery | TCP が loss から回復する流れを説明する |
| 09 | TLS: handshake、certificate、key | ClientHello、ServerHello、certificate chain、SNI、ALPN | TLS handshake metadata | 暗号化前に見える情報を識別する |
| 10 | HTTP: request、response、cache | method、header、status code、cache header | `curl -v`、ログ、packet output | 1つの HTTP exchange を説明する |
| 11 | HTTP/2 and QUIC: stream と multiplexing | frame、stream、multiplexing、HTTP/2 と QUIC transport の違い | negotiated protocol と stream behavior | transport ごとの stream behavior を比較する |
| 12 | End-to-End: domain name から encrypted web request まで | DNS、TCP または QUIC、TLS、HTTP のつながり | 1つの complete request path | 各 layer の役割を順に説明する |

## Current Entry Point

Start with [BGP Lab 01: One Prefix Announcement You Can Explain](labs/bgp-01-as-prefix-announcement.md). It is the first complete lab in the sequence and introduces the read-run-observe style used throughout Protocol Lab.

日本語: 最初は [BGP Lab 01: One Prefix Announcement You Can Explain](labs/bgp-01-as-prefix-announcement.md) から始めてください。このLabで、Protocol Lab 全体で使う「読む、動かす、観察する」の進め方を体験できます。
