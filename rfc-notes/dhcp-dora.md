# DHCP Reading Guide for Lab 22

This guide helps you read the RFC sections that matter for Lab 22. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、Lab 22 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 2131: DHCP](https://www.rfc-editor.org/rfc/rfc2131)
- [RFC 2132: DHCP Options](https://www.rfc-editor.org/rfc/rfc2132)

## Reading Goal

For this lab, read DHCP as *how a host with no address, and no knowledge of any server, bootstraps a full network configuration in four broadcast-based messages*.

日本語: このLabでは、DHCP を「アドレスも無く、サーバのことも知らないホストが、broadcast ベースの4メッセージでネットワーク設定一式を起動する仕組み」として読みます。

Start with these ideas:

- A client with no IP must use broadcast to reach an unknown server.
- The exchange is four messages: Discover, Offer, Request, Ack (DORA).
- The server hands out a temporary lease plus options (router, DNS, lease time).

## Lab #22 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 2131 | 3.1 | DORA の流れ(アドレス取得の全体) |
| 2 | RFC 2131 | 4.1 | broadcast、ポート 67/68、xid で対応づけ |
| 3 | RFC 2131 | 2 | メッセージ形式(BOOTP ベース) |
| 4 | RFC 2132 | 3, 9.6 | option: subnet(1)、router(3)、DNS(6)、lease(51)、message type(53) |

## なぜ broadcast か

RFC 2131 4.1。

- client は起動時、自分の IP もサーバの IP も知らない。
- だから宛先 `255.255.255.255`(limited broadcast)、送信元 `0.0.0.0` で、同じリンク上の全員に届ける。
- サーバだけが応答する。応答も(client がまだ IP を確定していないので)broadcast されうる。
- **xid**(transaction ID)で、どの Discover に対する Offer/Ack かを対応づける。

## DORA の4メッセージ

RFC 2131 3.1。DHCP option 53(message type)で種別を示す。

| メッセージ | 出す側 | 意味 |
|---|---|---|
| **Discover** | client | 「DHCP サーバいる?」(broadcast) |
| **Offer** | server | 「この住所どう?」候補提示 |
| **Request** | client | 「その住所をください」(broadcast、どのサーバを選んだかも示す) |
| **Ack** | server | 「確定。lease と option 付き」 |

- 複数サーバがいれば複数の Offer が来る。client は1つを選び、Request でそれを示す(他サーバは「断られた」と分かる)。
- 確定は **Ack**。Offer は候補にすぎない。

## lease(貸与)

RFC 2131、RFC 2132 option 51。

- アドレスは買い切りではなく、**期限付きの貸与**。
- client は期限前に更新(renew)する。更新しなければサーバはそのアドレスを再利用できる。
- これで、限りある(特に IPv4)アドレス空間を、出入りするホスト間で回せる。

## アドレス以外の option

RFC 2132。DHCP が配るのはアドレスだけではない。

| option | 番号 | 意味 |
|---|---|---|
| subnet mask | 1 | ネットワークの範囲 |
| router | 3 | default gateway |
| DNS | 6 | 名前解決に使うサーバ |
| lease time | 51 | 貸与の秒数 |
| message type | 53 | DORA の種別 |

- だから「DHCP でつながる」と、IP だけでなく gateway や DNS まで自動で入る。

## Message から読む

Lab の capture を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `0.0.0.0.68 > 255.255.255.255.67` | client からの broadcast(Discover/Request) |
| `DHCP-Message: Discover/Offer/Request/ACK` | option 53 の種別 |
| `Requested-IP: 10.0.0.193` | Request が要求するアドレス(option 50) |
| `lease of ... obtained` (udhcpc) | Ack を受けて設定完了 |

## よくある誤解

- Request は client が出す(サーバではない)。
- 確定は Ack。Offer は候補。
- broadcast の理由は「相手も自分の IP も知らない」から。
- アドレスは期限付き(lease)。恒久ではない。
- DHCP はアドレス以外(router/DNS/lease)も配る。
- ポートはサーバ 67 / client 68。

## 前後の Lab とのつながり

- Lab 20(NAT)や Lab 19(traceroute)は「アドレスがある前提」。DHCP はその「アドレスをどう得るか」。
- DHCP が配る router/DNS は、Lab 05(DNS)や経路の出発点。
- IPv6 では SLAAC(近隣探索ベース)や DHCPv6 という別の仕組みがある(発展)。
