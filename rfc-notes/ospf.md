# OSPF Reading Guide for Lab 34

This guide points at the material that matters for Lab 34. OSPF is the classic link-state interior gateway protocol: routers flood descriptions of their links, every router builds the same map, and each runs Dijkstra (SPF) to compute shortest paths by cost.

日本語: この guide は Lab 34 の読みどころを整理したものです。OSPF は代表的な link-state の IGP です——各ルータが自分のリンクの情報を flood し、全ルータが同じ地図を作り、各自が Dijkstra(SPF)で cost 最短経路を計算します。

Target material:

- [RFC 2328: OSPF Version 2](https://www.rfc-editor.org/rfc/rfc2328) — the full protocol (adjacencies, LSAs, SPF, areas)
- [RFC 2328 §7–10](https://www.rfc-editor.org/rfc/rfc2328) — the neighbor/adjacency state machine and Hello protocol
- [RFC 5340: OSPF for IPv6 (OSPFv3)](https://www.rfc-editor.org/rfc/rfc5340) — the IPv6 variant (for comparison)

## Reading Goal

Read OSPF as *"flood the map, then everyone computes the same shortest-path tree."* Unlike BGP (a path-vector protocol that advertises reachability with an AS_PATH and picks by policy), OSPF gives every router in an area an identical **link-state database** and each independently runs **SPF** to pick lowest-**cost** paths. Change a link and the flooded update triggers a fresh SPF — that is convergence.

日本語: OSPF は「地図を flood し、全員が同じ最短経路木を計算する」と読みます。BGP(到達性を AS_PATH 付きで広告し policy で選ぶ path-vector)と違い、OSPF は area 内の全ルータに同一の **link-state database** を配り、各自が **SPF** で最小 **cost** 経路を選ぶ。リンクが変われば flood された更新が新しい SPF を起こす——それが収束。

Start with these ideas:

- Routers discover neighbors with **Hello** packets and form **adjacencies** (Full state).
- Each floods **LSAs** (link-state advertisements) describing its links and cost.
- Every router assembles the same **LSDB** and runs **SPF (Dijkstra)** on it.
- Path selection is by **cost** (a metric), not hop count; ties can be ECMP.

## Lab #34 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | RFC 2328 §7, §10 | Hello / 隣接状態機械(Down→...→Full)、DR/BDR |
| 2 | RFC 2328 §12, §16 | LSA と LSDB、SPF(Dijkstra)の計算 |
| 3 | RFC 2328 §1.2 | area の概念(この Lab は単一 area 0) |

## adjacency(隣接)を作る

RFC 2328 §7, §10。

- ルータは各インターフェースで **Hello** を送り、隣接候補を見つける。
- 状態が Down→Init→2-Way→ExStart→Exchange→Loading→**Full** と進む。**Full** で LSDB を完全同期した隣接になる。
- **network type** が重要:
  - **broadcast**(Ethernet 既定): DR/BDR を選挙し、DROther 同士は 2-Way 止まり(DR/BDR とだけ Full)。
  - **point-to-point**(/30 のルータ間リンク向き): DR 選挙なし、相手と直接 Full。
  - この Lab の /30 リンクは **point-to-point** に設定して即 Full にする(既定の broadcast だと DR 選挙で 2-Way に留まりやすい)。

## LSA を flood し、LSDB を作る

RFC 2328 §12。

- 各ルータは自分のリンク(相手・cost)を **Router LSA** に書いて area 全体に flood する。
- 全ルータが同じ **LSDB**(link-state database)を持つ。Lab では `show ip ospf database` に3つの Router LSA(r1/r2/r3 各1)が見える。
- これが link-state の肝: **地図そのもの**を配る(BGP は「宛先への道」を配る path-vector)。

## SPF(Dijkstra)と cost

RFC 2328 §16。

- 各ルータは LSDB を入力に **Dijkstra** を回し、自分を根とする **最短経路木**を作る。
- 距離は **cost**(リンクのメトリック)の合計。既定 cost = 参照帯域/リンク帯域(FRR 既定 参照 100 Mbps)。この Lab は明示的に各リンク cost 10 に設定。
- Lab の例: r1→target(r3 の裏)は、直リンク r1-r3 経由 cost 20 と、r1-r2-r3 経由 cost 30。**低い方(直 20)**が選ばれる。hop 数ではなく cost で決まる。
- cost が同点なら複数経路(ECMP、Lab 32)になりうる。

## 収束(reconvergence)

- リンクが落ちると、隣接が切れ、関係ルータが更新 LSA を flood する。
- 各ルータが LSDB を更新し **SPF を再計算**して新しい経路を入れる。これが収束。
- Lab: 直リンク r1-r3 を落とすと、r1 は SPF をやり直し、target への経路が r2 経由(cost 30)に切り替わる。宛先アドレスは不変で到達性は維持。

## OSPF と BGP(Lab 01–04)の対比

| | OSPF (IGP, link-state) | BGP (EGP, path-vector) |
|---|---|---|
| 配るもの | リンク状態(地図) | 宛先+AS_PATH(道) |
| 経路計算 | 各自が Dijkstra(SPF) | best-path 選択(policy/AS_PATH) |
| メトリック | cost(合計) | 多段の属性(local-pref, AS_PATH長…) |
| 範囲 | 1つの管理ドメイン(area) | AS 間 |
| 用途 | 組織内の最短経路 | インターネットの経路交換 |

## Message から読む(Lab の出力)

| 見えるもの | 意味 |
|---|---|
| `2.2.2.2 Full/- ... eth1` | r2 と Full 隣接(LSDB 同期済み) |
| `show ip ospf database` に Router LSA ×3 | 各ルータが自リンクを広告、全員が同じ地図 |
| `O>* 10.0.30.0/24 [110/20] via 10.0.13.2` | OSPF 経路、距離110/cost20、直リンク経由 |
| 障害後 `[110/30] via 10.0.12.2` | SPF 再計算で r2 経由(cost30)に収束 |

## よくある誤解

- **OSPF は hop 数で選ぶ**、と思う。**cost**(メトリック合計)で選ぶ。低速リンクは高 cost。
- **Ethernet で即 Full になる**、と思う。broadcast 型は DR 選挙があり DROther 同士は 2-Way 止まり。ルータ間 /30 は point-to-point 型にする。
- **OSPF が経路そのものを配る**、と思う。配るのは **リンク状態(地図)**。経路は各自が SPF で計算する。
- **cost 同点で1本になる**、と思う。同点は ECMP になりうる(Lab 32)。
- **BGP と同じ**、と思う。BGP は path-vector/AS 間、OSPF は link-state/ドメイン内。役割が違う。

## 前後の Lab とのつながり

- BGP(Lab 01–04)の対になる IGP。実網は「内側 OSPF/IS-IS、外側 BGP」で組む。
- 収束の考え方は anycast(31)の BGP フェイルオーバーと通じるが、こちらは SPF 再計算による。
- cost 同点は ECMP(Lab 32)に、Hello/隣接は multicast(224.0.0.5/6、Lab 29)に触れる。
