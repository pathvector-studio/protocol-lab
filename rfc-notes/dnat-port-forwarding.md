# DNAT / Port Forwarding Reading Guide for Lab 40

This guide points at the material that matters for Lab 40. Destination NAT (port forwarding) is the inbound half of network address translation — it rewrites the destination of a packet so an external client can reach an internal service through a public address. The primary references are the NAT terminology and behaviour RFCs plus the conntrack model shared with Lab 20.

日本語: この guide は Lab 40 の読みどころを整理したものです。Destination NAT(ポートフォワード)は NAT の入り方向の半分で、パケットの宛先を書き換えて、外部クライアントが公開アドレス経由で内部サービスへ届けるようにする。主に NAT の用語・挙動の RFC と、Lab 20 と共通の conntrack モデルを挙げます。

Target material:

- [RFC 2663: IP NAT Terminology and Considerations](https://www.rfc-editor.org/rfc/rfc2663) — NAT vs NAPT, the translation model
- [RFC 3022: Traditional IP NAT](https://www.rfc-editor.org/rfc/rfc3022) — basic NAT and NAPT (port translation)
- [RFC 7857: Updates to NAT Behavioral Requirements](https://www.rfc-editor.org/rfc/rfc7857) — connection tracking and timeouts

## Reading Goal

Read DNAT as *"the outside reaches a chosen inside service through a public address:port."* Source NAT (Lab 20) rewrites the **source** of outbound packets so many inside hosts share one public address. DNAT rewrites the **destination** of inbound packets so a public `address:port` is mapped onto a specific internal `host:port` — a *port forward* or *published service*. The kernel tracks the flow so replies are un-NATed back automatically.

日本語: DNAT は「外側が、公開アドレス:ポート経由で、選ばれた内側サービスに届く」と読みます。Source NAT(Lab 20)は outbound の **送信元** を書き換え、多数の内側ホストが1つの公開アドレスを共有できるようにする。DNAT は inbound の **宛先** を書き換え、公開 `アドレス:ポート` を特定の内部 `ホスト:ポート` に写す——*ポートフォワード*(公開サービス)。カーネルが flow を追跡するので、応答は自動で un-NAT される。

Start with these ideas:

- **SNAT** rewrites the source (outbound, many→one); **DNAT** rewrites the destination (inbound, published service).
- DNAT happens in **PREROUTING** — before the routing decision — so the packet is then routed to the internal host.
- **conntrack** records the mapping; the reply's source is rewritten back to the public address.
- The internal host's return path must go **through the gateway** (its default route) so the reply is un-NATed.

## Lab #40 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | RFC 3022 | basic NAT と NAPT(ポート変換)。DNAT の位置づけ |
| 2 | RFC 2663 | NAT の用語(inside/outside, translation) |
| 3 | RFC 7857 | conntrack のタイムアウト/状態 |

## SNAT と DNAT(方向の違い)

RFC 3022。

| | SNAT (Lab 20) | DNAT (この Lab) |
|---|---|---|
| 書き換える | **送信元** | **宛先** |
| 方向 | outbound(内→外) | inbound(外→内) |
| 目的 | 多数の内側が1公開 IP を共有 | 内側サービスを公開アドレスで届ける |
| チェイン | POSTROUTING | PREROUTING |
| 例 | masquerade | port forward / 公開サービス |

- 2つは対。SNAT は「出て行く」を可能にし、DNAT は「入ってくる」を特定サービスに限って可能にする。

## DNAT はどこで起きるか

- iptables の **nat テーブル / PREROUTING チェイン**: パケットが入り、**ルーティング判断の前** に宛先を書き換える。
- Lab の規則: `iptables -t nat -A PREROUTING -d 203.0.113.1 -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.2:80`。
  - 公開 `203.0.113.1:8080` 宛のパケットの宛先を `10.0.0.2:80`(内部サーバ)に書き換える。
  - その後 gw は書き換わった宛先 `10.0.0.2` へルーティング(内部インターフェース経由で転送)。
- クライアントは内部 IP を知らない。公開アドレス:ポートだけを使う。

## conntrack と戻り(un-NAT)

RFC 7857。

- DNAT した flow は conntrack に記録される。Lab の例:

```text
src=203.0.113.2 dst=203.0.113.1 sport=... dport=8080
src=10.0.0.2    dst=203.0.113.2 sport=80  dport=...
```

- 1行目は「行き」(クライアント→公開)、2行目は自動で導かれる「戻り」(内部サーバ→クライアント)。
- 内部サーバの応答(src=10.0.0.2:80)は gw を通るとき **src を公開 203.0.113.1:8080 に戻して** クライアントへ。だからクライアントは公開アドレスから返ってきたように見える。
- **戻り経路が肝**: 内部サーバの default route が gw を指していないと、応答が gw を通らず un-NAT されない。Lab はサーバの default gw を gw にしてある。

## Message から読む(Lab の出力)

| 見えるもの | 意味 |
|---|---|
| before: `<unreachable>` | 公開ポートに何も無い(未公開) |
| `DNAT tcp dpt:8080 to:10.0.0.2:80` | ポートフォワード規則 |
| after: `server` | 公開アドレス経由で内部サーバに到達 |
| conntrack の `dport=8080 → src=10.0.0.2:80` | 宛先が内部に書き換わった証拠 |

## よくある誤解

- **DNAT と SNAT を混同する**。DNAT は宛先(入)、SNAT は送信元(出)。チェインも PREROUTING と POSTROUTING で別。
- **戻り経路を忘れる**。内部サーバは gw を経由して返さないと un-NAT されず、非対称で壊れる。
- **ファイアウォールが要らないと思う**。DNAT は届けるだけ。誰に公開するかは firewall(Lab 36)で絞る。DNAT + FORWARD 許可の設計。
- **ポート番号は同じと思う**。公開 8080 → 内部 80 のように付け替えられる(NAPT)。
- **hairpin(内側から公開 IP)を仮定する**。内側クライアントが公開 IP でアクセスするには追加の NAT(hairpin/NAT reflection)が要る。この Lab は外側からのみ。

## 前後の Lab とのつながり

- Lab 20(SNAT / masquerade)の対。SNAT=出、DNAT=入。同じ conntrack 基盤。
- L4 ロードバランサ(Lab 33 の IPVS NAT)は DNAT を複数 backend に広げたもの。
- stateful firewall(Lab 36)と組み合わせて「公開はするが誰に許すか制御する」境界を作る。
