# TCP Handshake and Teardown Reading Guide for Lab 07

This guide helps you read the RFC sections that matter for TCP Lab 07. It is meant to be used alongside the RFC, not instead of it.

日本語: この guide は、TCP Lab 07 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFC:

- [RFC 9293: Transmission Control Protocol (TCP)](https://www.rfc-editor.org/rfc/rfc9293)

RFC 9293 は、TCP の現行仕様。古い RFC 793 とその更新をまとめて置き換えたもの。以前の資料で 793 を参照している場合は、9293 の対応する章を読むとよい。

## Reading Goal

For this lab, read TCP setup and teardown as a negotiation of sequence numbers, captured as packets you can point at.

日本語: このLabでは、TCP の接続確立と切断を「sequence number の合意」として読み、その合意が packet としてどう見えるかに結びつけます。

Start with these ideas:

- TCP gives a reliable, ordered byte stream over unreliable IP.
- To do that, both ends must agree on where each direction's byte numbering starts (the ISN).
- The three-way handshake is that agreement.
- SYN and FIN each consume one sequence number, which is why acks are `seq + 1`.
- Each direction closes independently, so teardown is (up to) four packets.

## Lab #7 で読む場所

| 優先 | RFC 9293 | 章 | 読む目的 |
|---|---|---|---|
| 1 | 3.1 | control bits(SYN/ACK/FIN/RST)と header |
| 2 | 3.5 | 3-way handshake の手順 |
| 3 | 3.4 | sequence number、ISN、`ack = seq + 1` |
| 4 | 3.6 | FIN による termination(4-way close) |
| 5 | 3.3.2 | 状態遷移図(LISTEN → ... → TIME-WAIT) |

## 3-Way Handshake

RFC 9293 3.5 の中心。3つのパケットで双方向の初期 seq を同期する。

```text
client -> server : SYN,  seq = x
server -> client : SYN,ACK, seq = y, ack = x + 1
client -> server : ACK,  ack = y + 1
```

読みどころ:

- SYN は「この方向の byte 番号を x から始める」という宣言。
- ACK は「x+1 を次に期待する」= x までの SYN を受け取った、の意味。
- server も自分の SYN(seq=y)を返し、client がそれを ACK して、両方向が確定する。

1往復(2パケット)では片方向しか同期できない。だから3パケットが要る。

## Sequence Number と ISN

RFC 9293 3.4。seq は byte を数える番号で、開始値(ISN)はランダムに選ばれる。

- ランダムなのは、古い接続のパケットの取り違えや、番号の推測を避けるため。
- SYN と FIN は「1 byte 分」seq を消費する(データはないが番号を1つ進める)。だから相手の ack は `seq + 1` になる。

`tcpdump` は既定で **相対 seq**(接続内で 1 から)を表示するので、絶対 ISN を覚える必要はない。関係(`ack = 相手の seq + 1`)を追う。

## 4-Way Teardown

RFC 9293 3.6。各方向を独立に閉じる。

```text
client -> server : FIN
server -> client : ACK
server -> client : FIN
client -> server : ACK
```

- client の FIN は「client → server 方向はもう送らない」。
- でも server → client 方向はまだ開いていてよい(half-close)。
- server が送り終えたら FIN を送り、client が ACK して両方向が閉じる。

実装や負荷によっては、server の ACK と FIN が1パケットにまとまる(`[F.]`)こともある。だから見えるパケット数は3〜4になりうる。

## 状態遷移

RFC 9293 3.3.2 の図を、Lab の capture に対応づける(client 視点)。

| 状態 | いつ | capture での目印 |
|---|---|---|
| SYN-SENT | SYN を送った直後 | 最初の `[S]` |
| ESTABLISHED | handshake 完了 | 3つ目の `[.]` の後 |
| FIN-WAIT-1 | 自分の FIN 送信 | client からの `[F.]` |
| FIN-WAIT-2 | その FIN が ACK された | server からの `[.]` |
| TIME-WAIT | 相手の FIN を ACK 後 | 最後の `[.]` の後、しばらく待つ |

TIME-WAIT は、遅れて届くパケットを吸収するための待機。capture 上はパケットとしては見えないが、`ss -tan` などで状態として観察できる。

## tcpdump のフラグ表記

Lab の出力を RFC の control bits に対応づける。

| tcpdump | control bits |
|---|---|
| `[S]` | SYN |
| `[S.]` | SYN, ACK |
| `[.]` | ACK |
| `[P.]` | PSH, ACK |
| `[F.]` | FIN, ACK |
| `[R]` / `[R.]` | RST(, ACK) |

`.` は ACK ビットを表す。だから確立後のほとんどのパケットに `.` が付く。

## DNS トラックとのつながり

- DNS では「名前 → アドレス」を引いた。
- TCP はそのアドレスへ、実際に信頼できる接続を張る層。
- Lab 07 は接続の始まりと終わりに集中する。途中でパケットが失われたらどうなるか(再送・windowing)は Lab 08 で扱う。

## よくある誤解

- handshake は1回ではなく3パケット。
- seq の絶対値ではなく関係(`ack = seq + 1`)を読む。
- `[.]` は「空」ではなく ACK パケット。
- FIN(行儀のよい終了)と RST(打ち切り)は別物。
- 閉じるのは方向ごと(half-close)。

## 次の Lab につながる問い

- パケットが途中で失われたら、TCP はどうやって気づき、どう回復するのか。
- receive window は送信量をどう制限するのか。
- RTT は再送のタイミングにどう効くのか。

これらは Lab 08(retransmission、windowing、loss)で扱う。
