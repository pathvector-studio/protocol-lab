# NAT Reading Guide for Lab 20

This guide helps you read the RFC sections that matter for Lab 20. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、Lab 20 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 2663: NAT Terminology](https://www.rfc-editor.org/rfc/rfc2663)
- [RFC 3022: Traditional NAT](https://www.rfc-editor.org/rfc/rfc3022)
- [RFC 1918: Private Internet Address Allocation](https://www.rfc-editor.org/rfc/rfc1918)

## Reading Goal

For this lab, read NAT as *rewrite the source address on the way out, remember the mapping, reverse it on the way back*. The server only ever sees the NAT's public address.

日本語: このLabでは、NAT を「出口で送信元アドレスを書き換え、対応を覚え、帰りに戻す」ものとして読みます。server が見るのは常に NAT の public アドレスだけ。

Start with these ideas:

- Private addresses (RFC 1918) are reused everywhere and cannot appear on the public Internet.
- NAT rewrites the source address (and port, for NAPT) to one public address.
- A connection-tracking table remembers each mapping so replies reach the right inside host.

## Lab #20 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 1918 | 3 | private アドレス空間 10/8・172.16/12・192.168/16 |
| 2 | RFC 3022 | 2 | traditional NAT の基本(送信元アドレス変換) |
| 3 | RFC 3022 | 2.2 | NAPT(ポートも使って多重化) |
| 4 | RFC 2663 | 3-4 | inside/outside、binding、用語の整理 |

## private と public

RFC 1918。

- `10.0.0.0/8`、`172.16.0.0/12`、`192.168.0.0/16` は **private**。組織内で自由に使えるが、world で重複するので public 網には出せない。
- public アドレスは世界で一意。数が足りないので、多数の private ホストが少数の public アドレスを共有する必要がある。
- このLabでは `192.168.10.0/24` を private、`203.0.113.0/24`(RFC 5737 doc)を "public" 役として使う。

## source NAT / masquerade

RFC 3022 2。

- 出ていくパケットの **送信元アドレス** を、NAT の public アドレスに書き換える。
- Linux の `MASQUERADE` は、出口インターフェースの IP を自動で使う source NAT。固定 public IP を明示する `SNAT` の簡便版。
- 書き換え後、パケットは普通に public 網を流れる。相手(server)には NAT の public アドレスから来たように見える。

## NAPT(ポート多重化)

RFC 3022 2.2。

- 1つの public IP を多数の内側ホストで共有するには、アドレスだけでは足りない(戻りを区別できない)。
- そこで **送信元ポート** も使う。`(private IP, sport)` を `(public IP, 新 sport)` に対応づける。
- これで数万の同時接続を1つの public IP に収容できる。多くの家庭用ルータがこれ(NAPT / PAT)。

## connection tracking

- NAT は変換の対応表(Linux では **conntrack**)を持つ。
- 各エントリ: 元の tuple `(src, dst, sport, dport)` と、変換後の tuple。
- 応答が来たら、変換後 tuple から元 tuple を引き、宛先を内側ホストへ書き戻す。
- Lab の `conntrack -L` 出力の2組の tuple が、まさにこの対応。

## 非対称性

- **内→外**: conntrack が自動でエントリを作るので通る。
- **外→内**: 対応するエントリが無いと、NAT はどの内側ホストへ渡すか分からない。だから届かない。
- 特定サービスを外に公開するには **destination NAT / port forwarding** を明示的に設定する(このLabの範囲外)。
- 「NAT の内側は外から繋がりにくい」のはこの非対称性のため。ファイアウォールの代わりではないが、副作用として外部からの無差別接続を減らす。

## Message から読む

Lab の出力を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| server capture の src = NAT public | source NAT が効いている |
| private アドレスが public 側に出ない | 内側が隠れている |
| `conntrack -L` の2つの tuple | 元 ↔ 変換後 の binding |
| server ログの peer = NAT public | server は NAT としか話していないと認識 |

## よくある誤解

- NAT = firewall ではない。主目的はアドレス変換。
- server は private アドレスを見ない。NAT public だけ。
- conntrack が無いと応答を戻せない。NAT の心臓部。
- inbound は自動で通らない。port forwarding が要る。
- private アドレスは public に出せない(RFC 1918)。

## 前後の Lab とのつながり

- Lab 19(traceroute)で「経路上のルータ」を見た。NAT もルータ上の機能の一つ。
- private/public の区別は、VPN(Lab 16)や overlay(Lab 18)で「どのアドレス空間か」を考える土台。
- inbound の難しさ(NAT 越え)は、STUN/TURN、UPnP、そして end-to-end 接続性の議論につながる。
