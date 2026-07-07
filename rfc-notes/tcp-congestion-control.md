# TCP Congestion Control Reading Guide for Lab 30

This guide points at the material that matters for Lab 30. TCP congestion control is defined by a core RFC (the classic loss-based algorithm) plus the model-based BBR design; CUBIC and BBR are the two the lab compares.

日本語: この guide は Lab 30 の読みどころを整理したものです。TCP の輻輳制御は、古典的な loss-based の中核 RFC と、model-based の BBR で構成されます。Lab はこの CUBIC と BBR を比較します。

Target material:

- [RFC 5681: TCP Congestion Control](https://www.rfc-editor.org/rfc/rfc5681) — slow start, congestion avoidance, the loss-based core
- [RFC 8312: CUBIC for Fast and Long-Distance Networks](https://www.rfc-editor.org/rfc/rfc8312) — Linux's default, a loss-based algorithm tuned for high BDP
- [BBR: Congestion-Based Congestion Control](https://research.google/pubs/pub45646/) — the model-based approach (bottleneck bandwidth × RTT)

## Reading Goal

Read congestion control as *the sender's guess at how fast it may send*. TCP has no dial for "the link is 100 Mbit/s" — it must **infer** the available rate from feedback (ACKs, loss, delay) and adjust a **congestion window (cwnd)**. The lab's whole point is that *what signal you treat as "too fast" changes the answer* on a lossy path.

日本語: 輻輳制御は「送信側が、どれだけ速く送ってよいかを推測する仕組み」として読みます。TCP に「このリンクは 100 Mbit/s」というダイヤルは無く、feedback(ACK・loss・delay)から使える速度を **推測** し、**congestion window (cwnd)** を調整します。Lab の核心は、「何を『速すぎる』の合図とみなすか」で、lossy な path では答えが変わる、という点です。

Start with these ideas:

- **cwnd** limits how many bytes may be in flight (unacked) at once. Rate ≈ cwnd / RTT.
- **Loss-based** control (Reno, CUBIC) reads a *packet drop* as "too fast" and shrinks cwnd.
- **Model-based** control (BBR) estimates *bottleneck bandwidth* and *RTT* and paces to that, largely ignoring random drops.
- On a path with **random** (non-congestive) loss, the two diverge sharply.

## Lab #30 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | RFC 5681 §3 | slow start / congestion avoidance / cwnd と ssthresh の基本ループ |
| 2 | RFC 8312 §3–5 | CUBIC の cwnd 成長曲線(loss 後の回復)と高 BDP 向けの狙い |
| 3 | BBR 論文 §2–3 | bottleneck bandwidth × RTT を推定して pacing する model-based の発想 |

## cwnd と「in-flight」

RFC 5681 §2–3。

- **congestion window (cwnd)**: 送信側が管理する、ACK されていない(in-flight)バイト数の上限。
- 実効速度 ≈ **cwnd / RTT**。同じ cwnd でも RTT が大きいほど遅くなる(長距離が不利)。
- 送信可能量は `min(cwnd, receiver window)`。この Lab は cwnd 側が縛る領域を見る。
- **ssthresh**(slow start threshold): slow start と congestion avoidance の境目。loss 後に下がる。

## loss-based:Reno と CUBIC

RFC 5681 / RFC 8312。

- **slow start**: cwnd を ACK ごとに倍々で増やす(指数的)。ssthresh に達したら avoidance へ。
- **congestion avoidance**: cwnd を 1 RTT に約1 MSS ずつ増やす(線形)。
- **loss を輻輳とみなす**: パケットドロップ(3 dup ACK / タイムアウト)を見ると「送りすぎ」と解釈し cwnd を大きく削る(Reno は半分)。
- **CUBIC**: 削った後の回復を三次関数(cubic)曲線で行い、高 BDP でも速く復帰する。Linux の既定。だが依然 **loss = 輻輳** の前提。
- 問題: **ランダムな(輻輳でない)loss**——無線・軽度のビットエラー・軽い netem——でも cwnd を削るので、実効速度が「MSS / (RTT・√p)」程度(Mathis 近似)に落ちる。RTT が大きく p が小さくない path で顕著。

## model-based:BBR

BBR 論文。

- loss を輻輳の合図として使わない。代わりに **bottleneck bandwidth (BtlBw)** と **round-trip propagation time (RTprop)** を継続的に推定する。
- 送信を **pace**(等間隔化)して、推定 BtlBw に合わせる。cwnd は主に BDP = BtlBw × RTprop の数倍に置く。
- ランダムな loss があっても、それを「帯域が減った」証拠が無い限り速度を落とさない。
- 結果: lossy・長 RTT の path で loss-based より遥かに高い throughput を維持できる(この Lab の観察)。
- 注意: BBR は再送も出す(loss はある)が、**cwnd を折らない**。だから Lab では BBR の方が絶対再送数はむしろ多い一方、throughput は高い。

## Message から読む(ss -ti)

`ss -tin` の1本のフローから、輻輳制御の状態が読める。

| 見えるもの | 意味 |
|---|---|
| `cubic` / `bbr` | そのソケットの輻輳制御アルゴリズム |
| `cwnd:15 ssthresh:9`(CUBIC) | loss で cwnd/ssthresh が小さく抑えられている |
| `cwnd:276 bbr:(bw:100181184bps ...)`(BBR) | BBR が約100 Mbit の帯域を推定し、大きな cwnd を許す |
| `pacing_rate 99179368bps`(BBR) | 推定帯域に合わせた pacing(≈99 Mbit) |
| `bytes_retrans` / `retrans:` | 再送。BBR は多くても cwnd を折らない |
| `delivery_rate` | 実際に届いた速度の推定 |

## unicast の速度は誰が決めるのか

- リンク帯域・RTT・loss は path が決める。だが **どれだけ使えるかは送信側の輻輳制御が決める**。
- 同じ lossy path でも、CUBIC は 12 Mbit、BBR は 88 Mbit——アルゴリズム選択で 7 倍以上変わりうる。
- だから「遅い」の原因は必ずしも帯域不足ではなく、loss × RTT × 輻輳制御の相互作用のことがある。

## よくある誤解

- **loss = 必ず輻輳**、と思う。無線やビットエラーの loss は輻輳でない。loss-based はそれでも折る。
- **BBR は loss を無視する = 信頼性を捨てる**、と思う。再送はする(信頼性は TCP が担保)。折らないのは *cwnd* だけ。
- **速度はリンク帯域だけで決まる**、と思う。RTT と輻輳制御が同じくらい効く。
- **BDP を忘れる**。cwnd が BDP より小さいと、loss が無くても帯域を使い切れない。
- **公平性を無視する**。BBR と CUBIC を同一ボトルネックで混ぜると公平性の議論がある(この Lab の範囲外)。

## 前後の Lab とのつながり

- Lab 08(netem の delay/loss と再送・window)の続き。あそこで見た loss/RTT が、ここで throughput をどう決めるかに直結する。
- Lab 28(tc tbf shaping)と同じ tc を、ここでは path 障害(netem)として使う。ボトルネックの作り方は同系統。
- QUIC(Lab 11)は輻輳制御をユーザ空間に持ち、同じ原理(cwnd, pacing, BBR/CUBIC)を独自に実装する。
