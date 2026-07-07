# BFD Reading Guide for Lab 35

This guide points at the material that matters for Lab 35. BFD (Bidirectional Forwarding Detection) is a tiny, protocol-independent hello mechanism whose only job is to notice, very fast, that forwarding to a neighbor has stopped — so a routing protocol can react in milliseconds instead of tens of seconds.

日本語: この guide は Lab 35 の読みどころを整理したものです。BFD(Bidirectional Forwarding Detection)は、プロトコル非依存の極小 hello 機構で、唯一の仕事は「隣への転送が止まった」ことを **超高速** に気づくこと——routing プロトコルが数十秒ではなく数ミリ秒で反応できるように。

Target material:

- [RFC 5880: Bidirectional Forwarding Detection (BFD)](https://www.rfc-editor.org/rfc/rfc5880) — the protocol, sessions, and timers
- [RFC 5881: BFD for IPv4 and IPv6 (Single Hop)](https://www.rfc-editor.org/rfc/rfc5881) — running BFD directly between neighbors
- [RFC 5882: Generic Application of BFD](https://www.rfc-editor.org/rfc/rfc5882) — how OSPF/BGP consume a BFD "down"

## Reading Goal

Read BFD as *"a fast dead-man's switch for a next-hop."* Routing protocols already detect failure via their own hellos, but their timers are slow (OSPF's default dead interval is 40 s). BFD exchanges minimal packets several times a second; when a few in a row go missing, it declares the session down and tells the routing protocol immediately. Crucially, this catches failures where the **link stays up** but forwarding is broken.

日本語: BFD は「next-hop 用の高速なデッドマンスイッチ」と読みます。routing プロトコルも自前の hello で障害を検出しますが、タイマが遅い(OSPF 既定の dead 間隔は 40 秒)。BFD は極小パケットを毎秒数回やり取りし、数回連続で来なければ session down と判断して routing に即通知する。肝心なのは、**リンクは up のまま**転送だけ壊れた障害も捕まえられること。

Start with these ideas:

- A **BFD session** runs between two neighbors, exchanging control packets at a negotiated interval.
- Detection time ≈ **receive interval × detect multiplier** (e.g. 300 ms × 3 ≈ 900 ms).
- BFD carries no routing info; it just says **up/down** for the path to a neighbor.
- A routing protocol (OSPF, BGP) **registers** with BFD and drops the neighbor the instant BFD says down.

## Lab #35 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | RFC 5880 §6.8 | session state、timer 交渉、detection time の式 |
| 2 | RFC 5881 | 隣接ノード間(single hop)での動かし方 |
| 3 | RFC 5882 | OSPF/BGP が BFD の down をどう使うか |

## なぜ routing の hello だけでは遅いのか

- OSPF は Hello を 10 秒ごと、dead を 40 秒に持つ(Lab 34 / この Lab で確認)。40 秒間、壊れた経路を使い続けうる(blackhole)。
- 間隔を詰めれば速くなるが、Hello は重め(隣接維持のため)で、詰めすぎると CPU/帯域負荷や誤検出が増える。
- そこで **検出専用の軽量プロトコル(BFD)** を別に走らせ、routing はそれに「down を教えて」と登録する。役割分担: routing は経路計算、BFD は高速検出。

## BFD の timer と detection time

RFC 5880 §6.8.7。

- 各側が **desired min TX interval** と **required min RX interval** を広告し、両者で実効間隔を交渉する。
- **detect multiplier**(既定 3)= 何個連続で取りこぼしたら down とみなすか。
- 検出時間 ≈ **(相手の TX 間隔) × (自分の detect multiplier)**。この Lab は 300ms × 3 = **約 900ms**。
- OSPF の 40 秒に対し、約 **40 倍速い**。

## silent failure(この Lab の肝)

- リンクが **down** になれば、OS が即座に carrier loss を検出でき、routing もすぐ反応する(Lab 34 の veth はこれで ~1 秒だった)。
- しかし現実には、**リンクは up のまま転送だけ壊れる**ことがある: 間に挟まった dumb な L2 スイッチや media converter、片方向障害、wedged した隣接ルータ。
- このとき carrier は生きているので、routing は自分の hello が dead 間隔ぶん切れるまで(OSPF なら 40 秒)気づけない。
- **BFD はこの穴を埋める**: 制御パケットが来なくなれば ~900ms で down を宣言する。Lab では eth2 に `iptables DROP` を入れ、リンクを up のまま転送を殺して、この状況を再現する。

## OSPF/BGP との結合

RFC 5882。

- OSPF は `ip ospf bfd`、BGP は `neighbor X bfd` で、その隣接に BFD を紐づける。
- BFD が down を報告すると、routing は隣接を即 down 扱いにし、SPF/best-path をやり直す(再収束)。
- BFD は **意思決定しない**。ただ up/down を報告するだけ。経路をどうするかは routing の仕事。

## Message から読む(Lab の出力)

| 見えるもの | 意味 |
|---|---|
| `peer 10.0.13.2 ... Status: up` | r1–r3 間の BFD session が確立 |
| `Receive/Transmission interval: 300ms`, `Detect-multiplier: 3` | 検出時間 ≈ 900ms |
| OSPF `Dead 40s` | BFD 無しなら 40 秒待つ dead 間隔 |
| `eth2 ... UP,LOWER_UP`(障害中) | リンクは up のまま(silent failure) |
| `reconverged ... ~918 ms` | BFD 検出→OSPF 再収束が 1 秒未満 |

## よくある誤解

- **BFD が経路を選ぶと思う**。選ばない。up/down を報告するだけ。経路は OSPF/BGP が決める。
- **リンク down なら BFD が要ると思う**。リンク down は OS が即検出する。BFD の真価は **silent failure**(リンク up・転送死)。
- **hello を詰めれば十分と思う**。routing の hello を過度に詰めると負荷・誤検出増。軽量な BFD を分けるのが定石。
- **BFD だけで動くと思う**。BFD は routing(OSPF/BGP)と結合して初めて再収束を起こす。
- **速いほど良いと思う**。攻めすぎると瞬断で誤 down(フラップ)。環境に合わせた timer/multiplier を選ぶ。

## 前後の Lab とのつながり

- Lab 34(OSPF)の直接の続き。同じ三角形に BFD を足し、silent failure での再収束を速める。
- BGP(Lab 01–04)にも同様に付けられる(`neighbor X bfd`)。IGP/EGP どちらの高速検出にも使う。
- anycast(31)や ECMP(32)の「経路が消えたら別へ」も、検出が速いほど切り替えが速い——BFD はその検出段を担う。
