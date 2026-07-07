# Policy Routing Reading Guide for Lab 38

This guide points at the material that matters for Lab 38. Policy routing is a Linux mechanism (multiple routing tables selected by rules) rather than a single RFC, so the primary references are the `ip-rule`/`ip-route` manuals plus the source-address-selection and multihoming RFCs for context.

日本語: この guide は Lab 38 の読みどころを整理したものです。ポリシールーティングは単一 RFC ではなく Linux の仕組み(規則で選ぶ複数のルーティングテーブル)なので、主に `ip-rule`/`ip-route` のマニュアルと、背景として送信元選択・マルチホーミングの RFC を挙げます。

Target material:

- [ip-rule(8) manual page](https://man7.org/linux/man-pages/man8/ip-rule.8.html) — the rule database that selects a table
- [RFC 3704: Ingress Filtering for Multihomed Networks](https://www.rfc-editor.org/rfc/rfc3704) — why source matters for multihoming
- [RFC 1122 §3.3.4](https://www.rfc-editor.org/rfc/rfc1122) — the classic "route by destination" model policy routing extends

## Reading Goal

Read policy routing as *"the routing decision can depend on more than the destination."* Ordinary forwarding looks up the destination address in one table and picks the longest match. Policy routing puts a **rule database** in front: rules are checked in priority order, and the first matching rule chooses *which table* to consult. A rule can match on **source address**, incoming interface, firewall mark, ToS, and more — so two packets to the same destination can take different paths.

日本語: ポリシールーティングは「経路判断は宛先だけに依らなくてよい」と読みます。通常の転送は宛先アドレスを1つのテーブルで引き、最長一致を選ぶ。ポリシールーティングはその前に **規則データベース** を置く: 規則を優先度順に見て、最初に一致した規則が *どのテーブルを引くか* を決める。規則は **送信元アドレス**・入力インターフェース・firewall mark・ToS などで一致でき、同じ宛先への2パケットが別経路を通りうる。

Start with these ideas:

- Linux has **multiple routing tables** (main, local, and custom numbered ones).
- The **rule database** (`ip rule`) maps packets → a table, checked in priority order.
- A rule can select by **source**, iif, fwmark, etc. — not just destination.
- The first matching rule wins; unmatched packets fall through to `main`.

## Lab #38 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | ip-rule(8) | rule データベース、優先度、`from`/`iif`/`fwmark` セレクタ |
| 2 | ip-route(8) の `table` | 複数テーブルの作り方・引き方 |
| 3 | RFC 3704 | マルチホーミングで source が効く理由 |

## 通常の転送(宛先ベース)

RFC 1122 §3.3.4。

- 転送は宛先アドレスを1つのテーブル(`main`)で引き、**最長一致**の経路を使う。
- 送信元が誰でも、同じ宛先なら同じ経路。Lab のベースラインがこれ: srcA も srcB も `10.0.100.1` を main table の `default via up1` で引くので、両方 up1 に届く。

## 複数テーブルと rule データベース

ip-rule(8)。

- Linux は複数の **routing table** を持てる(番号やエイリアスで区別)。`ip route ... table 200` で別テーブルに経路を入れる。
- **rule データベース** が「どのパケットがどのテーブルを引くか」を決める。`ip rule` で見える:

```text
0:     from all lookup local
32765: from 10.0.5.2 lookup 200
32766: from all lookup main
32767: from all lookup default
```

- **優先度が小さい順**に評価し、最初に一致した規則のテーブルで経路解決する。
- Lab の規則(prio 32765)は「送信元が 10.0.5.2(srcB)なら table 200 を引け」。table 200 は `default via up2`。だから srcB は up2 へ。srcA は一致せず main(via up1)に落ちる。

## セレクタ(何で振り分けるか)

ip-rule(8)。

- **from**(送信元アドレス/prefix): この Lab で使用。送信元 LAN ごとに別 ISP、など。
- **iif**(入力インターフェース): どの口から入ったかで振る。
- **fwmark**: iptables/nftables で付けたマークで振る(L4 情報や DPI 結果と連携)。
- **tos/dsfield**: ToS/DSCP で振る(QoS 連携)。
- これらで「宛先以外」を経路判断に持ち込める。

## どこで使うか

RFC 3704。

- **マルチホーミング / 複数 ISP**: 「この LAN の送信元は ISP-A、あの LAN は ISP-B」。戻りも source に合った ISP から出す(非対称回避)。
- **VPN スプリット**: 特定 source/mark だけ VPN テーブルへ。
- **帯域分離**: マークしたトラフィックを別経路/別品質へ。
- 送信元に基づく分離は、ingress filtering(RFC 3704)とも整合する(自分の source は自分の ISP から出す)。

## Message から読む(Lab の出力)

| 見えるもの | 意味 |
|---|---|
| baseline: `srcA=up1 srcB=up1` | 宛先ベース。両者同じ経路 |
| `ip rule ... from 10.0.5.2 lookup 200` | srcB の source を table 200 へ振る規則 |
| `table 200: default via up2` | その別テーブルの経路 |
| after: `srcA=up1 srcB=up2` | 同じ宛先が source で別経路に |

## よくある誤解

- **経路は宛先だけで決まると思う**。policy routing は source/iif/mark 等でも決められる。
- **rule と route を混同する**。**rule** はどのテーブルを引くか、**route** はそのテーブル内の経路。2段構え。
- **規則の優先度を無視する**。小さい順に評価し最初の一致が勝つ。main(32766)より前に置かないと効かない。
- **戻り経路を忘れる**。source ベースで送っても、戻りが別経路だと非対称になり RPF やステートフル機器で落ちうる(RFC 3704)。
- **fwmark を使わず source だけと思う**。L4 やアプリ単位で振るには iptables で mark → `fwmark` 規則、という定石がある。

## 前後の Lab とのつながり

- ECMP(Lab 32)は同じ宛先を複数経路に「hash で」散らす。policy routing は「規則で明示的に」振る。目的が別。
- fwmark 連携は stateful firewall(Lab 36)や QoS(Lab 28)と組み合わさる(mark して振る)。
- マルチホーミングの戻り非対称は RPF(reverse path filtering)と関わる。source を正しい出口に固定する土台。
