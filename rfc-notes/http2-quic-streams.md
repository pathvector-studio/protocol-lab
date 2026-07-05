# HTTP/2, HTTP/3, and QUIC Streams Reading Guide for Lab 11

This guide helps you read the RFC sections that matter for Lab 11. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、Lab 11 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 9113: HTTP/2](https://www.rfc-editor.org/rfc/rfc9113)
- [RFC 9114: HTTP/3](https://www.rfc-editor.org/rfc/rfc9114)
- [RFC 9000: QUIC](https://www.rfc-editor.org/rfc/rfc9000)
- [RFC 7301: ALPN](https://www.rfc-editor.org/rfc/rfc7301)

## Reading Goal

For this lab, read HTTP/2 and HTTP/3 as two ways to multiplex streams — the difference is what carries the streams.

日本語: このLabでは、HTTP/2 と HTTP/3 を「stream を多重化する2つの方法」として読みます。違いは、その stream を何が運ぶか。

Start with these ideas:

- HTTP semantics (methods, status, headers) stay the same across versions.
- What changes is the transport and how concurrency is expressed.
- HTTP/2 multiplexes streams over one TCP connection.
- HTTP/3 multiplexes streams over QUIC, which runs on UDP.

## Lab #11 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 9113 | 5 | HTTP/2 の stream と多重化 |
| 2 | RFC 9113 | 4 | frame(stream に分けて運ぶ単位) |
| 3 | RFC 9000 | 2 | QUIC の stream(独立配送) |
| 4 | RFC 9114 | 2 | HTTP/3 を QUIC stream に対応づける |
| 5 | RFC 7301 | 3 | ALPN で h2 / h3 を選ぶ |

## Stream と多重化

HTTP/1.1 は1接続で1リクエストずつ(Lab 10)。同時に複数やりたければ、複数 TCP 接続を張った。

HTTP/2 は、1本の接続の中に **stream** を作る。

- 各リクエスト/レスポンスは1つの stream(奇数番号は client 始動)。
- データは **frame** に分割され、stream 番号を付けて1本の接続にインターリーブされる。
- 受信側は stream 番号で組み立て直す。

これで「1接続1リクエスト」の制約が消える。Lab では、3リクエストを投げても SYN が1つ(1接続)であることで確認する。

## TCP Head-of-Line Blocking

HTTP/2 は HTTP 層の HoL を消したが、下は1本の TCP。

- TCP は「順番どおりのバイトストリーム」を保証する。
- あるセグメントが失われると、TCP はそれを再送するまで、後続を上位に渡さない。
- すると、その1つの loss が、同じ接続の**全 stream** を止める(TCP head-of-line blocking)。

多重化しても、下が単一の順序付きストリームである限り、この stall は残る。

## QUIC が解くこと

RFC 9000。QUIC は UDP の上に、transport を丸ごと作り直す。

- 暗号化(TLS 1.3 相当を内蔵)、信頼性(再送)、順序、そして **stream** を QUIC 自身が持つ。
- stream ごとに独立して配送される。ある stream の loss は、その stream だけを待たせ、他は進める。
- だから TCP head-of-line blocking を、stream 間では避けられる。

HTTP/3(RFC 9114)は、HTTP の各やり取りを QUIC の stream に乗せたもの。

## なぜ UDP なのか

- TCP はカーネルと中間装置に深く根付いていて、順序保証も固定。stream 独立配送を後付けできない。
- UDP は「そのまま届ける」だけの薄い層。その上に QUIC が自由に transport を実装できる。
- だから QUIC は UDP を土台に選んだ。ただの UDP 送信ではなく、UDP の上の完全な transport。

## Discovery: ALPN と Alt-Svc

- client はまず TCP で来て、TLS の **ALPN** で `h2`(または `http/1.1`)を選ぶ(Lab 09 参照)。
- server は **`Alt-Svc: h3=":443"`** ヘッダで「同じサービスを h3 でも受けられる」と広告する。
- client はそれを覚えて、次回 QUIC(UDP)で h3 を試す。

Lab では、HTTP/2 応答の `Alt-Svc` ヘッダでこの広告を読む。

## 変わらないもの

- method、status code、header(Lab 10)の意味は、h1 / h2 / h3 で同じ。
- 変わるのは framing(どう分割するか)、多重化(どう同時に流すか)、transport(TCP か QUIC/UDP か)。
- つまり「何を言うか」ではなく「どう運ぶか」が進化している。

## よくある誤解

- HTTP/2 の多重化と、HTTP/1.1 の複数接続並列は別物。
- HTTP/2 でも TCP head-of-line blocking は残る。QUIC がそれを解く。
- QUIC は「ただの UDP」ではない。UDP の上の完全な transport。
- HTTP の semantics はバージョンで変わらない。
- HTTP/3 の観察は client(curl)の対応に依存する。

## 次の Lab につながる問い

- ここまでで DNS → TCP → TLS → HTTP(/2/3)を個別に見た。
- これらを1つの Web request として、順につなげると何が起きるのか。

これは Lab 12(end-to-end)で扱う。
