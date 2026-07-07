# GRE Tunnel Reading Guide for Lab 21

This guide helps you read the RFC sections that matter for Lab 21. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、Lab 21 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 2784: Generic Routing Encapsulation (GRE)](https://www.rfc-editor.org/rfc/rfc2784)
- [RFC 1701: Generic Routing Encapsulation (GRE)](https://www.rfc-editor.org/rfc/rfc1701)

## Reading Goal

For this lab, read GRE as the simplest, most generic Layer-3 tunnel: put a small GRE header in front of a payload and carry it directly in IP (protocol 47). It encapsulates; it does not encrypt.

日本語: このLabでは、GRE を「最も単純で汎用な L3 トンネル」として読みます。ペイロードの前に小さな GRE ヘッダを付け、IP に直接(プロトコル 47)載せて運ぶ。カプセル化はするが暗号化はしない。

Start with these ideas:

- GRE rides directly in IP as protocol 47 — not over UDP or TCP.
- It carries Layer-3 payloads (typically IP), with a tiny GRE header.
- It encapsulates but does not encrypt; pair it with IPsec for confidentiality.

## Lab #21 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 2784 | 2 | GRE パケット構造(delivery header + GRE header + payload) |
| 2 | RFC 2784 | 2.1 | GRE ヘッダのフィールド(最小構成) |
| 3 | RFC 2784 | 2.3 | Protocol Type、IP プロトコル番号 47 |
| 4 | RFC 1701 | 1 | GRE の背景と設計思想 |

## GRE のパケット構造

RFC 2784 2。外側から内側へ:

```text
[ delivery header (outer IP, proto=47) ][ GRE header ][ payload (inner IP ...) ]
```

- **delivery header**: 外側の IP ヘッダ。プロトコル番号は **47**(= GRE)。UDP/TCP は挟まない。
- **GRE header**: 最小では 4 バイト(flags + protocol type)。オプションで key/sequence/checksum を足せる。
- **payload**: 運ぶ中身。Protocol Type が中身の種別を示す(IPv4 なら 0x0800)。

## IP に直接載る

- VXLAN(UDP 4789)や WireGuard(UDP 51820)は UDP を使うが、GRE は **IP プロトコル 47 として IP に直接**載る。
- capture のフィルタは transport ポートではなく `proto 47`(または `proto gre`)。
- UDP を挟まないぶんヘッダは小さいが、UDP の利点(NAT/LB 越えやポートでの識別)は得られない。

## L3 を運ぶ

- GRE の payload は通常 **IP パケット**(L3)。だから overlay インターフェースには IP を付ける。
- VXLAN は Ethernet フレーム(L2)を運ぶので、broadcast/L2 セグメントの延伸ができる。GRE にはそれは無い(L3 のみ)。
- GRE で L2 を運びたい場合は、拡張の **GRETAP**(Ethernet over GRE)を使う(このLabの範囲外)。

## encapsulation ≠ encryption

- GRE はカプセル化だけ。**暗号化しない**。だから underlay を capture すると内側 IP が平文で読める。
- 機密性が要るなら **IPsec** と組み合わせる(GRE over IPsec)。GRE がカプセル化と routing 適合性を、IPsec が暗号化を担う、という分業。
- これは Lab 18(VXLAN も非暗号)と同じ教訓: カプセル化と暗号化は別の機能。

## 3つのトンネルの位置づけ

| Lab | 運ぶ層 | 暗号化 | on the wire |
|---|---|---|---|
| 16 WireGuard | L3 (IP) | あり | UDP 51820, 暗号文 |
| 18 VXLAN | L2 (Ethernet) | なし | UDP 4789, 内側フレーム可視 |
| 21 GRE | L3 (IP) | なし | IP proto 47, 内側 IP 可視 |

- 「運ぶ層(L2/L3)」と「暗号化(有/無)」は独立した2軸。3つはその組み合わせの別の点。
- GRE = 「L3 を、暗号化せず」包む、最も素朴なトンネル。

## Message から読む

Lab の capture を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `proto GRE (47)` の外側 IP | GRE の delivery header(underlay) |
| `GREv0, Flags [none]` | 最小構成の GRE ヘッダ |
| その内側の `10.100.0.1 > 10.100.0.2: ICMP echo` | payload の inner IP(平文) |
| `ip -d link show gre1` の `gre remote ... local ...` | トンネル端点の設定 |

## よくある誤解

- GRE は暗号化しない。IPsec と組み合わせて初めて秘匿。
- GRE は UDP ではない。IP プロトコル 47。
- GRE は L3(IP)を運ぶ。L2 が要るなら GRETAP。
- 既定の gre0 は予約。別名を使う。
- overlay と underlay のアドレスは別物。

## 前後の Lab とのつながり

- Lab 16(WireGuard)と Lab 18(VXLAN)と並べて、トンネルの設計軸(層・暗号)が一望できる。
- GRE + OSPF や GRE over IPsec は、実運用の VPN/WAN で広く使われる構成。
- 「カプセル化と暗号化は別」という視点は、overlay ネットワーク全般の理解の土台。
