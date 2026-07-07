# ARP Reading Guide for Lab 24

This guide helps you read the RFC that matters for Lab 24. It is meant to be used alongside the RFC, not instead of it.

日本語: この guide は、Lab 24 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 826: An Ethernet Address Resolution Protocol](https://www.rfc-editor.org/rfc/rfc826)
- [RFC 1122: Requirements for Internet Hosts](https://www.rfc-editor.org/rfc/rfc1122)

## Reading Goal

For this lab, read ARP as the simplest possible IP-to-MAC resolver: broadcast a question, get a unicast answer, cache it. Compare it with NDP (Lab 23), which does the same job on IPv6 with multicast.

日本語: このLabでは、ARP を「最も単純な IP→MAC 解決」として読みます。broadcast で問い、unicast で答えを得て、cache する。Lab 23 の NDP(IPv6 で同じ仕事を multicast で行う)と比べます。

Start with these ideas:

- A frame is delivered by MAC; ARP turns an IP address into that MAC.
- The request is broadcast to everyone; only the owner replies (unicast).
- The result is cached so you do not ask every time.

## Lab #24 で読む場所

RFC 826 は非常に短い。全体を読める。

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 826 | "Packet format" | hardware type、protocol type、op(1=request/2=reply)、sender/target |
| 2 | RFC 826 | アルゴリズム | 受信時の cache 更新と応答の条件 |
| 3 | RFC 1122 | 2.3.2 | ホストの ARP cache 要件(タイムアウトなど) |

## なぜ ARP が要るか

- IP アドレスは「どのホストか」を示すが、Ethernet はフレームを **MAC アドレス** で配送する。
- だから、同じリンク上の相手に送るには「相手の IP に対応する MAC」を知る必要がある。
- ARP はこの「IP → MAC」を、リンク上で問い合わせて解決する。

## ARP request / reply

RFC 826。

- **request(op=1)**: 「この IP の持ち主の MAC は?」。宛先を broadcast(`ff:ff:ff:ff:ff:ff`)にして全員へ。中身に sender(自分)の IP/MAC と target の IP を入れる。
- **reply(op=2)**: 該当者が「私です、MAC はこれ」。request の sender 情報が分かっているので、**unicast** で返せる。
- tcpdump 表記: `Request who-has <ip> tell <asker>` / `Reply <ip> is-at <mac>`。

## ARP cache

RFC 1122 2.3.2。

- 解決結果(IP→MAC)を cache する(`ip neigh`)。
- 以後の通信は cache を使い、毎回 broadcast しない。
- エントリは古くなると再確認される(STALE→再解決)。NDP の neighbor cache と同じ発想。

## ルータ越えの場合

- ARP は **同一リンク(L2)内** だけの仕組み。
- 別セグメントの相手に送るときは、まず経路表で next-hop(gateway)を決め、その **gateway の MAC** を ARP で引く。
- つまり「最終宛先の MAC」ではなく「次に渡す相手の MAC」を解決する。

## ARP と NDP の対比

| | ARP (IPv4) | NDP (IPv6) |
|---|---|---|
| 何の上 | 独自 EtherType 0x0806 | ICMPv6 |
| 問い合わせ先 | broadcast(全員) | solicited-node multicast(該当者) |
| request/reply | ARP request / reply | Neighbor Solicitation / Advertisement |
| cache | ARP table | neighbor cache |

- 役割は同じ。IPv6 は broadcast を廃し、的を絞った multicast に統一した。

## Message から読む

Lab の capture を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `> ff:ff:ff:ff:ff:ff ... Request who-has 10.0.0.2 tell 10.0.0.1` | broadcast の ARP request |
| `Reply 10.0.0.2 is-at <mac>`（unicast） | 該当者からの応答 |
| `ip neigh`: `10.0.0.2 lladdr <mac> REACHABLE` | 解決済みの ARP cache |

## よくある誤解

- IP だけで配送できると思う。リンク配送は MAC。
- reply も broadcast と思う。request は broadcast、reply は unicast。
- ARP がルータ越えで使えると思う。同一リンク内だけ。越える先は gateway の MAC を引く。
- cache しないと思う。一度引いたら cache する。
- NDP と別の仕事と思う。同じ IP→MAC。手段が違う。

## 前後の Lab とのつながり

- Lab 23(NDP)の IPv4 版。並べると broadcast→multicast の進化が見える。
- ARP は DHCP(Lab 22)でアドレスを得た後、実際に L2 で通信する土台。
- ARP spoofing はセキュリティの話題(このLabの範囲外)。「broadcast で誰でも答えられる」単純さの裏返し。
