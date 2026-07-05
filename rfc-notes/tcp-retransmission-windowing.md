# TCP Retransmission and Windowing Reading Guide for Lab 08

This guide helps you read the RFC sections that matter for TCP Lab 08. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、TCP Lab 08 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 9293: Transmission Control Protocol (TCP)](https://www.rfc-editor.org/rfc/rfc9293)
- [RFC 6298: Computing TCP's Retransmission Timer](https://www.rfc-editor.org/rfc/rfc6298)
- [RFC 7323: TCP Extensions for High Performance](https://www.rfc-editor.org/rfc/rfc7323)
- [RFC 5681: TCP Congestion Control](https://www.rfc-editor.org/rfc/rfc5681)

## Reading Goal

For this lab, read TCP as a control loop: it sends, waits for acknowledgment, and reacts when acknowledgments do not arrive.

日本語: このLabでは、TCP を「送って、ACK を待ち、来なければ反応する制御ループ」として読みます。loss にどう気づき、どう送り直し、どうペースを調整するかを追います。

Start with these ideas:

- TCP delivers a reliable stream over an unreliable network, so it must detect and repair loss.
- Loss is inferred, not signaled: a segment is assumed lost when it is not acknowledged.
- Two triggers: a retransmission timeout (RTO) and duplicate ACKs (fast retransmit).
- The RTO comes from measured RTT.
- Windows bound how much unacknowledged data can be in flight.

## Lab #8 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 9293 | 3.7 | data transfer、retransmission、window の使い方 |
| 2 | RFC 6298 | 2 | RTT サンプルから RTO を計算する式 |
| 3 | RFC 9293 | 3.8.6 | receive window と flow control |
| 4 | RFC 7323 | 2 | window scale option(16bit window の拡張) |
| 5 | RFC 5681 | 3.1-3.2 | loss 検出後の cwnd の下げ方(参考) |

## Loss をどう検出するか

TCP は「loss です」という信号を受け取らない。ACK が来ないことから推測する。

- **RTO タイムアウト**: あるセグメントを送って、RTO の時間内に ACK が来なければ再送する。保守的だが確実。
- **duplicate ACK / fast retransmit**: 受信側は「次に欲しい byte 番号」を ACK で繰り返す。抜けがあると同じ ACK が重複して届く。送信側は 3 回の dup ACK で、RTO を待たずに再送する。

Lab 08 では、netem の 15% loss がこの両方を引き起こす。`ss -tino` の `retrans:` と capture の同一 seq の再出現で観察する。

## RTO と RTT

RFC 6298 が RTO の作り方。

- SRTT(平滑化した RTT)と RTTVAR(RTT のばらつき)を測る。
- `RTO = SRTT + 4 * RTTVAR`(下限あり)。
- 再送してもまた失敗すると、RTO を指数的に伸ばす(backoff)。

だから RTT が伸びる(Lab では netem の delay)と RTO も伸びる。`ss` の `rtt:` と `rto:` を並べて見ると関係が分かる。

## 2つの Window

混同しやすいので分けて読む。

| 窓 | 誰が決める | 意味 |
|---|---|---|
| receive window (rwnd) | 受信側が広告 | 「今これだけ受け取れる」= flow control |
| congestion window (cwnd) | 送信側が内部で計算 | 「ネットワークにこれだけなら流せる」= congestion control |

実際に送れる未確認データ量は `min(rwnd, cwnd)`。

- rwnd は TCP header の 16bit window フィールド。足りないので **window scale option**(RFC 7323、SYN で交換)で左シフト量を決め、実効窓を広げる。
- cwnd は slow start / congestion avoidance で増減し、loss を検出すると下げる(RFC 5681)。capture には出ないが `ss` の `cwnd:` で見える。

## capture / ss の読み方

Lab の出力を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `win NNNN`(tcpdump) | その方向の advertised receive window |
| `wscale N`(SYN options) | window scale factor |
| 同一 `seq` の再出現 | 再送されたセグメント |
| `ss` `rtt:S/V` | 平滑化 RTT / ばらつき |
| `ss` `retrans:X/Y` | 現在未回復の再送 X / 累計再送 Y |
| `ss` `cwnd:N` | congestion window(セグメント数) |
| `ss` `rto:N` | 現在の retransmission timeout(ms) |

## Lab 07 とのつながり

- Lab 07 は接続の開始と終了(handshake / teardown)。
- Lab 08 は確立後のデータ転送と、loss への反応。
- 同じ2ノード構成を使い、netem を足しただけ。観察の焦点が「制御ビット」から「時間とカウンタ」へ移る。

## よくある誤解

- 再送は異常ではなく正常な回復動作。
- loss は明示的に通知されない。ACK が来ないことから推測される。
- receive window(受信側の広告)と cwnd(送信側の計算)は別物。
- window scale がないと、高遅延・高帯域リンクで window が足りず速度が出ない。
- tcpdump は再送にラベルを付けない。seq の再出現や ss のカウンタで判断する。

## 次の Lab につながる問い

- ここまでで、名前解決(DNS)と信頼できる転送(TCP)を見た。
- その TCP の上で、通信内容はどう暗号化されるのか。暗号化の前に何が平文で見えるのか。

これは Lab 09(TLS handshake、certificate、SNI/ALPN)で扱う。
