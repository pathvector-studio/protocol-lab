# Path MTU Discovery Reading Guide for Lab 25

This guide helps you read the RFC sections that matter for Lab 25. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、Lab 25 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 1191: Path MTU Discovery](https://www.rfc-editor.org/rfc/rfc1191)
- [RFC 791: Internet Protocol](https://www.rfc-editor.org/rfc/rfc791)
- [RFC 792: ICMP](https://www.rfc-editor.org/rfc/rfc792)

## Reading Goal

For this lab, read PMTUD as a feedback loop: send a packet you are not allowed to fragment, and if it is too big for some link, a router tells you the size that fits. Cache it and send within it.

日本語: このLabでは、PMTUD をフィードバックループとして読みます。分割禁止のパケットを送り、途中のリンクに大きすぎれば、ルータが「収まるサイズ」を教えてくれる。それを cache して、その範囲で送る。

Start with these ideas:

- Each link has an MTU; the path's usable MTU is the smallest link along it.
- A DF-marked packet that is too big is dropped, and ICMP frag-needed reports the next-hop MTU.
- The sender caches the path MTU and stays under it.

## Lab #25 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 1191 | 3 | PMTUD の考え方(DF + ICMP + 学習) |
| 2 | RFC 1191 | 4 | ICMP frag-needed の中の next-hop MTU フィールド |
| 3 | RFC 791 | 2.3 | fragmentation と DF フラグ |
| 4 | RFC 792 | Destination Unreachable | type 3 code 4(fragmentation needed) |

## MTU とボトルネック

- **MTU**: そのリンクが1フレームで運べる最大バイト数(Ethernet は普通 1500)。
- 経路上に MTU の小さいリンクが1つでもあれば、経路全体で送れる最大サイズ(**Path MTU**)はそこに制限される。
- 「経路の最狭 MTU」を知りたい、というのが PMTUD の動機。

## DF(Don't Fragment)

RFC 791 2.3。

- IP ヘッダのフラグ。「このパケットを途中で分割するな」。
- 昔はルータが大きいパケットを分割して通した(fragmentation)。だが分割は非効率で、reassembly の負荷や欠落時の全体再送などの問題がある。
- 現代は **DF を立てて分割させず**、代わりに PMTUD で正しいサイズを学ぶのが基本。TCP は既定で DF。

## ICMP fragmentation-needed

RFC 792 / RFC 1191 4。

- DF 付きパケットが、あるリンクの MTU より大きくて転送できないとき、ルータはそれを捨て、**ICMP Destination Unreachable, code 4(fragmentation needed and DF set)** を送信元に返す。
- RFC 1191 は、この ICMP に **next-hop MTU**(そのルータが扱える MTU)を載せることを定めた。だから送信側は「どこまで小さくすればよいか」が分かる。
- Lab の `need to frag (mtu 1400)` がこれ。

## 学習と cache

- 送信側は ICMP を受けて、その宛先(経路)への **path MTU** を学び、cache する(Linux では route cache、`ip route get` の `mtu`)。
- 以後はそのサイズ以下で送る。もっと先に細いリンクがあれば、また ICMP が来てさらに小さく学ぶ。
- PMTUD は「一度詰まって学ぶ」方式。初回の大きいパケットは落ちる(TCP は再送で調整)。

## black hole(有名なバグ)

- 途中のファイアウォールが ICMP frag-needed を落とすと、送信側は「詰まった」ことも「正しいサイズ」も分からない。
- DF 付きの大きいパケットが黙って消え続ける = **PMTUD black hole**。
- 症状: 小さいやり取り(HTML)は通るが、大きいレスポンス(画像・TLS の大きな handshake)で固まる。切り分けが難しい。
- 教訓: **ICMP を無闇に全部ブロックするな**。PMTUD が壊れる。回避策に TCP MSS clamping もある。

## IPv6 との違い

RFC 8201。

- IPv6 のルータは **絶対に分割しない**(fragmentation は送信元だけの仕事)。
- だから IPv6 では PMTUD が必須。大きすぎるパケットには **ICMPv6 Packet Too Big** が返る。
- 仕組みは IPv4 の PMTUD と同型。

## Message から読む

Lab の出力を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `Frag needed and DF set (mtu = 1400)` | ルータからの ICMP frag-needed(next-hop MTU 1400) |
| `ICMP ... need to frag (mtu 1400)` | type 3 code 4 の capture 表記 |
| `ip route get ...: mtu 1400` | 学習・cache された path MTU |
| `-M do` | ping で DF を立てる指定 |

## よくある誤解

- MTU = パケットサイズではない。MTU はリンク上限。パケットはその中に収める。
- DF が無いと PMTUD は起きない(古い挙動では分割されて通る)。
- ICMP をブロックすると PMTUD が壊れる(black hole)。
- path MTU は宛先(経路)ごとに学習・cache される。
- 初回の大きいパケットは落ちる。学んでから小さくする。

## 前後の Lab とのつながり

- Lab 19(traceroute)と同じく「経路上のルータの振る舞い」を見る。
- TCP(Lab 07/08)は DF を使うので、PMTUD が効かないと大きな転送で詰まる。
- tunnel(Lab 16/18/21)はヘッダのぶん実効 MTU が減るので、PMTUD/MSS の考慮が実運用で重要になる。
