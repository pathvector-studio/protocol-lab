# traceroute and TTL Reading Guide for Lab 19

This guide helps you read the RFC sections that matter for Lab 19. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、Lab 19 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 791: Internet Protocol](https://www.rfc-editor.org/rfc/rfc791)
- [RFC 792: ICMP](https://www.rfc-editor.org/rfc/rfc792)
- [RFC 1812: Requirements for IP Version 4 Routers](https://www.rfc-editor.org/rfc/rfc1812)

## Reading Goal

For this lab, read TTL as a loop-protection counter that traceroute repurposes into a mapping tool. The key is the router behavior: decrement, and on zero, send ICMP time-exceeded.

日本語: このLabでは、TTL を「ループ防止のカウンタ」として読み、それを traceroute が地図作成の道具に転用する、と理解します。鍵はルータの振る舞い: 減算し、0 になったら ICMP time-exceeded を返す。

Start with these ideas:

- Every IP packet has a TTL; each router decrements it by one.
- At zero, the router drops the packet and sends ICMP time-exceeded back to the source.
- traceroute sends probes with TTL 1, 2, 3, … so each router in turn reveals itself.

## Lab #19 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 791 | 3.2 "Time to Live" | TTL フィールドの意味とホップごとの減算 |
| 2 | RFC 792 | "Time Exceeded Message" | TTL 0 で返す ICMP、type 11 |
| 3 | RFC 1812 | 5.3.1 | ルータの TTL 処理(減算・破棄・time-exceeded 生成) |

## TTL — ループ防止のカウンタ

RFC 791 3.2。

- TTL は IP ヘッダの 8bit フィールド。本来の目的は「経路がループしてもパケットが永遠に回り続けないようにする」保険。
- 各ルータは**転送するたびに TTL を1減らす**。減算結果が 0 なら、そのパケットは捨てる。
- 元は「秒」の意図だったが、実際にはホップ数として扱われる。

## ICMP time-exceeded

RFC 792。

- ルータが TTL を 0 にして捨てるとき、送り主へ **ICMP time-exceeded**(type 11, code 0 = in-transit)を返す。
- この ICMP の **送信元 IP が、そのルータのアドレス**。だから「どのルータで死んだか」が分かる。
- 中身には、死んだ元パケットの先頭が含まれる(どの probe への応答かを対応づけるため)。

## traceroute のトリック

- 宛先へ **TTL=1** の探査を送る → 最初のルータで 0 → そのルータが time-exceeded を返す → **hop 1** 判明。
- **TTL=2** → 2番目のルータで死ぬ → **hop 2**。
- TTL を増やしていくと、距離ごとに1台ずつルータが答える。
- 十分大きい TTL で宛先に届くと、宛先は time-exceeded ではなく通常の応答(ICMP echo reply や UDP port-unreachable など、probe 種別による)を返す → 経路の終わり。

probe の種別:
- **ICMP**(`traceroute -I`): ICMP echo を使う(このLab)。
- **UDP**(既定): 高ポート宛 UDP。宛先は port-unreachable を返す。
- **TCP**(`-T`): SYN を使う。ファイアウォール越えに強い。

## forwarding と endpoint

- **ルータ(r1/r2)**: パケットを「通す」。TTL を減らし、0 なら time-exceeded を出す。`ip_forward=1`。
- **endpoint(client/server)**: パケットの終点/始点。TTL 処理で time-exceeded を出すのはルータの役目。

## Message から読む

Lab の出力を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| traceroute の各行(hop N + IP) | TTL=N の probe に答えたルータ |
| `10.0.1.2 > 10.0.1.1: ICMP time exceeded` | r1 が TTL 0 で返した ICMP |
| 最後の hop = 宛先 IP | 宛先に届いた(time-exceeded ではない) |
| `* * *`（実網） | ICMP を絞る/落とすルータ |

## よくある誤解

- TTL = 経過時間、ではない。実質ホップ数の上限。
- time-exceeded を出すのは宛先ではなくルータ。
- 最後の hop は time-exceeded ではない(宛先の通常応答)。
- 行き経路と帰り経路は違いうる。traceroute が見せるのは行き。
- 実網の `* * *` は障害とは限らない(ICMP 制限)。

## 前後の Lab とのつながり

- TCP(Lab 07/08)や上位のラボが「両端で何が起きるか」を見たのに対し、これは「経路上のルータが何をするか」。
- TTL は VXLAN/WireGuard(Lab 16/18)の overlay でも効く(inner と outer で別の TTL)。
- 経路の可視化は、ネットワーク障害切り分けの基本ツール。
