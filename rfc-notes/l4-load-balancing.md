# L4 Load Balancing Reading Guide for Lab 33

This guide points at the material that matters for Lab 33. Layer-4 load balancing is a mechanism (Linux IPVS here) rather than a single RFC, so the primary references are the IPVS/keepalived docs plus the load-balancing taxonomy in RFC 7424 and the NAT model in RFC 2663.

日本語: この guide は Lab 33 の読みどころを整理したものです。L4 ロードバランシングは単一 RFC ではなく仕組み(ここでは Linux IPVS)なので、主に IPVS/keepalived の資料と、負荷分散の分類(RFC 7424)・NAT モデル(RFC 2663)を挙げます。

Target material:

- [Linux Virtual Server (IPVS) HOWTO](http://www.linuxvirtualserver.org/Documents.html) — the director/real-server model and forwarding methods (NAT/DR/TUN)
- [RFC 2663: IP Network Address Translator (NAT) Terminology](https://www.rfc-editor.org/rfc/rfc2663) — the NAT that IPVS NAT-mode performs
- [RFC 7424: Optimizing LAG/ECMP Component Link Utilization](https://www.rfc-editor.org/rfc/rfc7424) — flow-based distribution context (shared with ECMP, Lab 32)

## Reading Goal

Read an L4 load balancer as *"one virtual address, a pool of real servers, and a director that assigns each connection to one of them."* Unlike anycast (routing picks an instance) or ECMP (routing spreads flows across links), here a single node **actively** distributes incoming connections and keeps per-connection state so the two directions match up.

日本語: L4 ロードバランサは「1つの仮想アドレス、実サーバのプール、そして各接続を1台へ割り当てる director」と読みます。anycast(routing がインスタンスを選ぶ)や ECMP(routing が flow をリンクに分散)と違い、ここでは1つのノードが **能動的に** 入ってくる接続を分配し、往復が対応するよう接続ごとの状態を持ちます。

Start with these ideas:

- A **VIP** (virtual IP) fronts a pool of **real servers**; clients only see the VIP.
- The **director** picks a real server per connection by a **scheduler** (round-robin, least-conn, hashing…).
- It works at **L4** (TCP/UDP + ports): it does not parse HTTP; it forwards connections.
- It keeps a **connection table** so every packet of a flow goes to the same backend and the reply is rewritten back to the VIP.

## Lab #33 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | IPVS HOWTO | director / real server、scheduler、NAT/DR/TUN の転送方式 |
| 2 | RFC 2663 | IPVS NAT モードが行うアドレス変換の用語 |
| 3 | RFC 7424 | flow 単位の分散(ECMP と共通の考え) |

## VIP と real server pool

IPVS HOWTO。

- クライアントは **VIP**(仮想 IP、例 `10.0.9.100`)に接続する。裏の実サーバ(backend)は見えない。
- director は VIP:port への接続を、**real server**(`10.0.10.11:80` など)へ転送する。
- 実サーバの追加・削除で、クライアント無変更にプールを増減できる(スケールアウト)。

## scheduler(どの backend を選ぶか)

- **rr**(round-robin): 順番に一巡。この Lab で使用。
- **wrr**(weighted rr): 重み付き(強いサーバに多く)。
- **lc / wlc**(least-connection): 接続数の少ないサーバへ。
- **sh**(source hashing): 送信元 IP の hash で固定(粘着性)。
- L4 なので HTTP の中身(URL/Cookie)は見ない。見るのは 5-tuple。中身で振るのは L7 LB(別物)。

## 転送方式(NAT / DR / TUN)

IPVS HOWTO。この Lab は **NAT**。

| 方式 | やること | 戻り経路 |
|---|---|---|
| **NAT (masq)** | 宛先を backend に書き換え(DNAT)。戻りは src を VIP に戻す | backend の default gw を director にする必要あり |
| **DR**(direct routing) | MAC だけ書き換え。backend が VIP を lo に持ち直接返す | director を経由しない(高速) |
| **TUN** | IPIP でカプセル化して backend へ | 同上 |

- NAT は設定が単純で、往復とも director を通る。Lab には最適。
- director は **接続テーブル**(IPVS conn)を持ち、同じ接続の全パケットを同じ backend に送り、戻りを VIP へ書き戻す。だから L4 の状態を持つ(ステートフル)。

## anycast(31)/ ECMP(32)との対比 — 負荷分散の三部作

| | 何が分散を決めるか | 単位 | 状態 |
|---|---|---|---|
| anycast (31) | routing の best-path | クライアント→1インスタンス | ステートレス(routing) |
| ECMP (32) | routing の multipath + hash | flow→1リンク | ステートレス(hash) |
| **LB (33)** | **director の scheduler** | **接続→1 backend** | **ステートフル(conn table)** |

- anycast/ECMP は「routing の副作用」で散る。LB は1ノードが **意図的に** 分配し、往復整合のため状態を持つ。

## Message から読む(Lab の出力)

| 見えるもの | 意味 |
|---|---|
| `TCP 10.0.9.100:80 rr` | VIP:port と scheduler(round-robin) |
| `-> 10.0.10.11:80 Masq` | real server と NAT(masq)転送 |
| 応答が backend1→2→3→1… | rr が接続ごとに一巡している |
| 30 リクエスト = 10/10/10 | プール全体へ均等分配 |

## よくある誤解

- **L4 LB が HTTP を見ていると思う**。見ない。URL/Cookie で振るのは L7 LB(reverse proxy)。L4 は接続を転送するだけ。
- **VIP が backend にあると思う**。NAT モードでは VIP は director 上。backend は自分の実 IP を持つ。
- **戻り経路を忘れる**。NAT モードは backend の default gw を director にしないと戻りが VIP に書き戻されない。
- **健全性チェックが自動と思う**。素の IPVS は死んだ backend も回し続ける。ヘルスチェックは keepalived 等が担う(この Lab の範囲外)。
- **粘着性(persistence)を仮定する**。既定の rr は接続ごとに散る。同一クライアントを固定するには sh か persistence を使う。

## 前後の Lab とのつながり

- 負荷分散の三部作の締め: anycast(31, routing が1つ選ぶ)、ECMP(32, routing が flow を散らす)、LB(33, director が接続を分配)。
- NAT(Lab 20)の DNAT/変換が土台。IPVS NAT は「宛先を backend に変え、戻りを VIP に戻す」DNAT。
- HTTP(Lab 10/27)の上位に立つ L7 LB(reverse proxy)への入口。L4 と L7 の役割分担を意識する。
