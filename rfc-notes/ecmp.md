# ECMP Reading Guide for Lab 32

This guide points at the material that matters for Lab 32. ECMP (equal-cost multipath) is a forwarding behaviour rather than a single protocol: when routing offers several equally-good paths, the router keeps them all and hashes traffic across them. The references cover why per-flow hashing is used and the routing that produces equal-cost paths.

日本語: この guide は Lab 32 の読みどころを整理したものです。ECMP(equal-cost multipath)は単一プロトコルではなく転送の振る舞いです——routing が同じ良さの経路を複数示したとき、ルータは全て保持し、トラフィックをそれらに hash で分配します。参照は、なぜ per-flow hashing なのかと、equal-cost 経路を作る routing を扱います。

Target material:

- [RFC 2992: Analysis of an Equal-Cost Multi-Path Algorithm](https://www.rfc-editor.org/rfc/rfc2992) — the hash-threshold / per-flow idea
- [RFC 4271: A Border Gateway Protocol 4 (BGP-4)](https://www.rfc-editor.org/rfc/rfc4271) — how BGP yields multiple equal paths (`maximum-paths`)
- [RFC 7424: Mechanisms for Optimizing LAG/ECMP Component Link Utilization](https://www.rfc-editor.org/rfc/rfc7424) — why real traffic hashes unevenly, and flow entropy

## Reading Goal

Read ECMP as *"several equally-good next-hops, chosen per flow by a hash."* The router does not stripe *packets* round-robin (that would reorder a single connection); it hashes each *flow* (usually the 5-tuple) to one next-hop, so a connection stays on one path while different connections spread out.

日本語: ECMP は「同じ良さの next-hop が複数あり、フローごとに hash で選ぶ」ものとして読みます。ルータは *パケット* をラウンドロビンで縞状に分けはしません(1接続が並べ替わるため)。各 *フロー*(通常は 5-tuple)を hash で1つの next-hop に対応させ、接続は1経路に固定しつつ、別々の接続が分散します。

Start with these ideas:

- Routing can install **multiple next-hops** for one prefix when their costs tie.
- The kernel picks a next-hop **per flow** by hashing packet fields — not per packet.
- What goes into the hash matters: **L3 (src/dst IP)** vs **L4 (also ports)**.
- If every flow shares the same IP pair, **L3 hashing pins them all to one link**; L4 hashing spreads them.

## Lab #32 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | RFC 2992 | per-flow(hash-threshold)方式と、なぜ per-packet にしないか |
| 2 | RFC 4271 §9.1 + `maximum-paths` | 複数の equal-cost 経路が RIB に載る条件 |
| 3 | RFC 7424 | 実トラフィックの偏り(flow entropy)と最適化の考え方 |

## equal-cost path はどこから来るか

RFC 4271 / FRR `maximum-paths`。

- BGP は既定で prefix ごとに best を1つだけ入れる(Lab 31 の anycast はこれを使った)。
- `maximum-paths N` を付けると、**同点の**経路を最大 N 本まで FIB に入れる(eBGP multipath)。同点とは、weight/local-pref/AS_PATH 長/MED などの比較で並ぶこと。
- この Lab では r1–r2 を **2本の並行リンク**で eBGP 接続し、両セッションが同じ prefix を同じ AS_PATH 長で広告する→ 2本が同点 → ECMP。
- FIB では next-hop group として見える:

```text
10.0.8.0/24 nhid 25 proto bgp
    nexthop via 10.0.12.2 dev eth2 weight 1
    nexthop via 10.0.13.2 dev eth3 weight 1
```

## per-flow hashing(なぜ per-packet でないか)

RFC 2992。

- 単純に1パケットずつ交互に送ると、同じ接続のパケットが別経路を通り、遅延差で **並べ替え(reordering)** が起きる。TCP は reordering を loss と誤認しかねない。
- そこで **flow 単位**で分ける。ルータは各パケットの識別子(通常 5-tuple: src/dst IP, protocol, src/dst port)を hash し、その値で next-hop を選ぶ。同じ flow は常に同じ next-hop → 1経路に固定 → 並べ替え無し。
- 別々の flow は別々の hash → 統計的に複数リンクへ散る。多数の flow があるほど均等に近づく(少数だと偏る、RFC 7424)。

## Linux の multipath hash policy(この Lab の肝)

- Linux は `net.ipv4.fib_multipath_hash_policy` で hash に何を含めるか決める:
  - `0`(既定): **L3** のみ(src/dst IP)。
  - `1`: **L4**(src/dst IP + protocol + ports)。
  - `2`: inner header(トンネル)など。
- **落とし穴**: すべての flow が同じ src/dst IP(例: 1台のクライアント→1台のサーバ)だと、L3 hashing では **全 flow が同じ hash → 1リンクに集中**。もう1本は使われない。
- ports を含む **L4 hashing(policy=1)** にすると、送信ポートが異なる各 flow が別々に散り、両リンクが使われる。
- Lab の観察:
  - policy=0 で 16 flow → ほぼ全部が片方(一方 133 GB、他方 151 bytes)。
  - policy=1 で 16 flow → ほぼ半々(131 GB / 133 GB)。

## anycast(Lab 31)との対比

| | anycast (Lab 31) | ECMP (Lab 32) |
|---|---|---|
| 経路数 | best を **1本** | 同点を **複数本** |
| 目的 | 同一アドレスの複数インスタンスから1つ選ぶ | 1宛先への複数リンクに負荷分散 |
| フェイルオーバー | 別インスタンスへ再収束 | 残るリンクへ hash し直す |
| 単位 | クライアント→1インスタンス | flow→1リンク |

- どちらも「routing が選ぶ」。anycast は best-path 選択(1本に絞る)、ECMP は multipath(複数を保つ)。

## Message から読む(Lab の出力)

| 見えるもの | 意味 |
|---|---|
| `nexthop via ... dev eth2` ×2 | 2本の equal-cost next-hop(ECMP がFIBに載った) |
| `fib_multipath_hash_policy = 1` | L4(ポート込み)で hash する |
| `eth2 delta 131GB / eth3 delta 133GB` | 両リンクがほぼ半々に使われた(policy=1) |
| policy=0 で片側 ~0 | 同一 IP ペアが L3 hashing で1リンクに集中(落とし穴) |

## よくある誤解

- **ECMP はパケットを交互に振る**、と思う。実際は **flow 単位**の hash(reordering 回避)。
- **常に均等**、と思う。flow 数が少ないと偏る。均等は多数 flow の統計的結果。
- **1本の接続が速くなる**、と思う。1 flow は1リンク止まり。ECMP は **多数の flow の総和**を増やす。
- **設定すれば勝手に両リンク使う**、と思う。同一 IP ペアなら L3 hashing で1本に集中する。ポートを hash に入れる必要がある。
- **LAG(bonding)と同じ**、と思う。似た hashing だが、LAG は L2 の1論理リンク、ECMP は L3 の複数経路。

## 前後の Lab とのつながり

- Lab 31(anycast)の双対。あちらは best を1本、こちらは同点を複数。BGP の同じ経路選択の別の面。
- 5-tuple の flow 概念は NAT(Lab 20)や輻輳制御(Lab 30)と共通。hash に入るポートは TCP/UDP のポート(Lab 07/10)。
- LAG/bonding(L2 版)や、DC の Clos ファブリックの負荷分散の基礎。
