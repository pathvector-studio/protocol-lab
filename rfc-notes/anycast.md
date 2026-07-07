# Anycast Reading Guide for Lab 31

This guide points at the material that matters for Lab 31. Anycast is not a single protocol but a *deployment technique*: announce the same address from several places and let routing pick one. The references cover the routing architecture that makes it work and its use for well-known services.

日本語: この guide は Lab 31 の読みどころを整理したものです。Anycast は単一のプロトコルではなく *配置の技法* です——同じアドレスを複数箇所から announce し、routing に1つ選ばせる。参照は、それを成立させる routing の枠組みと、著名サービスでの利用を扱います。

Target material:

- [RFC 4271: A Border Gateway Protocol 4 (BGP-4)](https://www.rfc-editor.org/rfc/rfc4271) — how a router picks one best path among many (AS_PATH etc.)
- [RFC 4786: Operation of Anycast Services](https://www.rfc-editor.org/rfc/rfc4786) — the operational how-to for anycast
- [RFC 7094: Architectural Considerations of IP Anycast](https://www.rfc-editor.org/rfc/rfc7094) — what anycast is and its trade-offs

## Reading Goal

Read anycast as *"one address, many instances, routing decides."* Nothing in the packet says "go to the nearest server" — the **routing system** already knows one best path to that prefix, and the packet simply follows it. Change the topology (an instance withdraws) and routing picks a different instance for the same address.

日本語: Anycast は「1つのアドレス、複数のインスタンス、routing が決める」と読みます。パケットには「最寄りへ」とは書かれていない——**routing** が既にその prefix への best path を1つ持ち、パケットはそれに従うだけ。トポロジが変われば(インスタンスが withdraw)、同じアドレスに対して別のインスタンスが選ばれます。

Start with these ideas:

- Several nodes announce the **same prefix** (e.g. `10.0.0.100/32`) into routing.
- Each router keeps **one best path** to that prefix — so each client is steered to one instance.
- "Nearest" means **nearest in routing terms** (AS_PATH length, IGP metric, local-pref), not geographic distance.
- If the chosen instance **withdraws** its route, routing reconverges onto another — automatic failover.

## Lab #31 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | RFC 4271 §9.1 | BGP の best-path 選択(AS_PATH 長など)——「1つ選ぶ」仕組み |
| 2 | RFC 4786 §3–5 | anycast の運用(同一 prefix の複数 announce、catchment、切り替え) |
| 3 | RFC 7094 §2 | anycast の定義と、状態を持つ通信での注意点 |

## anycast とは何か

RFC 7094 §2 / RFC 4786。

- 同一の IP prefix を、複数の物理的に離れたノードから routing に announce する。
- 各ルータは、その prefix への **best path を1つ**だけ RIB/FIB に入れる。だから、あるルータ配下のクライアントは常に「そのルータにとっての best」1インスタンスへ届く。
- 送信側は何も特別なことをしない。宛先はただの1つの IP。**どこへ行くかは routing が決める**。
- 対比: unicast=1対1、broadcast=セグメント全員、multicast=join した group、**anycast=同一アドレスの複数から routing が選んだ1つ**。

## 「最寄り」は routing 上の最寄り

RFC 4271 §9.1(best-path)。

- BGP は複数の候補パスから best を1つ選ぶ。主な決め手(上から):local-preference が高い、**AS_PATH が短い**、origin、MED、eBGP>iBGP、IGP metric が低い…
- この Lab では **AS_PATH 長**で決める。server-b は自分の AS を **prepend**(`set as-path prepend 65002 65002`)して path を長く見せ、server-a を優先させる。
- だから「nearest」は物理距離ではなく **routing metric 上の近さ**。実運用でも、地理ではなく BGP/IGP のトポロジが catchment(どのクライアントがどのインスタンスに落ちるか)を決める。

## 失敗時の切り替え(withdraw と再収束)

RFC 4786 §5。

- 選ばれたインスタンスのリンク/セッションが落ちると、その announce が **withdraw** される(またはセッション断で無効化)。
- ルータは残る候補から再び best を選び、FIB を更新する(**再収束**)。
- 同じ宛先アドレスのまま、トラフィックは別インスタンスへ流れる=**自動フェイルオーバー**。クライアント側の設定変更は不要。
- Lab では server-a のリンクを落とすと、r1 は数秒で server-b 経由へ切り替わり、同じ VIP が server-b から応答する。

## どこで使うか

- **DNS ルートサーバ / 権威 DNS**: 13 のルートサーバ「アドレス」は実際には多数の anycast インスタンス。最寄りへ落ちて低遅延・耐障害。
- **CDN / パブリック DNS**(例 `1.1.1.1`, `8.8.8.8`): 同じ IP が世界中に。
- **DDoS 吸収**: 攻撃トラフィックが多数のインスタンスに分散する。
- 主に **UDP やステートレス/短命な** 要求に向く(下記の注意)。

## 状態を持つ通信での注意

RFC 7094 §2。

- anycast の catchment は routing 変化で **移りうる**。長時間の TCP セッション中に best path が変わると、別インスタンスへ飛んで接続が切れる恐れ。
- だから古典的には DNS(UDP・1往復)に向く。TCP/TLS でも、収束が安定していれば実用されている(多くの CDN が HTTP anycast を運用)。
- インスタンス間の**状態共有**が要る用途では、別の仕組み(セッション同期・一貫ハッシュ等)を併用する。

## Message から読む(Lab の出力)

| 見えるもの | 意味 |
|---|---|
| `Paths: (2 available, best #2)` | r1 が VIP への2つの候補パスを持ち、1つを best に選んだ |
| `65001 ... best (AS Path)` | server-a の path(短い AS_PATH)が best |
| `65002 65002 65002` | server-b の prepend された path(長いので非優先) |
| `10.0.0.100 via 10.0.1.2`(before) | FIB は server-a 経由 |
| `wget http://10.0.0.100/ → server-a` | 実際に server-a が応答 |
| 失敗後 `via 10.0.2.2` / `→ server-b` | 再収束して server-b が同じ VIP に応答 |

## よくある誤解

- **anycast はロードバランサだと思う**。1クライアントは基本1インスタンスに固定的に落ちる(routing 上の best)。分散は「多数のクライアントが別々の best を持つ」ことで起きる。細かい負荷分散は別の仕組み。
- **「最寄り」=地理的**、と思う。実際は routing metric(AS_PATH/IGP)上の最寄り。
- **anycast は専用プロトコル**、と思う。ただの「同一 prefix の複数 announce」+ 通常の routing。
- **TCP に使えない**、と思う。収束が安定なら実用される。長寿命セッションの移動リスクを理解した上で。
- **IP が重複していて壊れる**、と思う。異なるセグメントにある限り、各ルータが1 best を持つので破綻しない。

## 前後の Lab とのつながり

- BGP の基礎(Lab 01–04)を実サービスに応用する回。best-path 選択(AS_PATH)がそのまま catchment を決める。
- multicast(Lab 29)との対比が効く: multicast=1送信を多数へ、anycast=多数の同一アドレスから1つへ。
- 実サービス側は HTTP(Lab 10/27)や DNS(Lab 05/06)——anycast はそれらを「どこからでも同じ IP で」提供する土台。
