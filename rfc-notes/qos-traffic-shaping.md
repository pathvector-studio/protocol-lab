# Traffic Shaping Reading Guide for Lab 28

This guide points at the material that matters for Lab 28. Traffic shaping is a Linux `tc` mechanism rather than a single RFC, so the primary reference is the `tc` manuals plus the DiffServ RFCs for context.

日本語: この guide は Lab 28 の読みどころを整理したものです。traffic shaping は単一の RFC ではなく Linux `tc` の仕組みなので、主に `tc` のマニュアルと、背景として DiffServ の RFC を挙げます。

Target material:

- [tc-tbf(8) manual page](https://man7.org/linux/man-pages/man8/tc-tbf.8.html)
- [RFC 2475: Differentiated Services Architecture](https://www.rfc-editor.org/rfc/rfc2475)
- [RFC 2697: Single Rate Three Color Marker](https://www.rfc-editor.org/rfc/rfc2697)

## Reading Goal

For this lab, read shaping as *metering egress to an average rate with a token bucket*. Tokens fill at the rate; a packet needs tokens to leave; the bucket size (burst) sets how much you can send at once.

日本語: このLabでは、shaping を「token bucket で egress を平均 rate に整える」ものとして読みます。トークンが rate で溜まり、パケットは送るのにトークンを要し、バケツの大きさ(burst)が一度に出せる量を決める。

Start with these ideas:

- A qdisc controls how packets leave an interface (order, timing, drop).
- A token bucket meters traffic to an average rate.
- burst (bucket size) and latency (max queue delay) shape the behavior.

## Lab #28 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | tc-tbf(8) | rate / burst / latency(または limit)のパラメータ |
| 2 | RFC 2697 | token bucket の一般形(committed rate/burst) |
| 3 | RFC 2475 | shaping/policing が DiffServ のどこに位置するか |

## qdisc(queueing discipline)

- Linux は各インターフェースの出口に **qdisc** を持ち、パケットの送出(順序・タイミング・破棄)を決める。
- `tc qdisc add/replace/del dev <if> root <qdisc>` で設定する。
- 既定は簡単な FIFO 系(pfifo_fast など)。netem(Lab 08)や tbf(このLab)も qdisc。

## token bucket(tbf)

tc-tbf(8)。

- **rate**: トークンが溜まる速さ(= 目標平均速度)。
- パケットを送るにはトークンが要る。あれば即送出、無ければ待つ(またはキュー)。
- **burst**(バケツの大きさ): 溜められるトークン量。瞬間的にまとめて出せる量。**バイト単位**。
  - 小さすぎると、各時刻に少ししか送れず、実効速度が rate を大きく下回る(Lab で `32kbit`=4KB にすると 0.5 Mbit まで低下)。
  - rate に見合ったサイズ(数十 KB)が要る。
- **latency**(または limit): パケットがキューで待てる最大時間(またはキュー長)。超えたら破棄。

## shaping と policing

RFC 2475。

| | shaping | policing |
|---|---|---|
| 超過分の扱い | キューに貯めて遅らせ、rate に整える | 即破棄 or 再マーク |
| 遅延 | 増える(バッファ) | 増えない |
| 例 | tbf, htb | tc police, ingress policer |

- tbf は **shaping**。超過分を捨てるのではなく、貯めて平均を rate に合わせる。

## どこで使うか

- **契約帯域の実現**: ISP が「100 Mbps プラン」を rate 制限で提供。
- **公平分配**: 1ユーザ/1フローが回線を占有しないよう上限を設ける。
- **遅い上流の保護 / bufferbloat 対策**: 上流リンクより少し低く shaping して、キューを自分側に持つ(fq_codel などと併用)。

## Message から読む

Lab の出力を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `baseline: 56551 Mbit/s` | 素の veth 速度(shaping 前) |
| `tbf rate 10mbit burst 32kb` | token bucket の設定 |
| `shaped: 9 Mbit/s` | 平均が rate 付近に整った |
| `tc -s qdisc show` の sent/dropped | qdisc の統計 |

## よくある誤解

- shaping と netem(遅延・損失)を混同する。目的が別。
- burst の単位はバイト。bit で小さく指定すると絞りすぎる。
- tbf は egress を絞る。ingress は別(ifb 等)。
- shaping は遅らせる、policing は捨てる。
- veth はとても速い。素の速度は環境依存。

## 前後の Lab とのつながり

- Lab 08(netem)と同じ tc の別機能(遅延・損失 vs 速度制限)。
- shaping は TCP の輻輳制御(Lab 08)と相互作用する(ボトルネックとして働く)。
- VLAN(Lab 26)の PCP や DiffServ DSCP は、優先度付き QoS へと発展する。
