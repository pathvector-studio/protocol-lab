# DNS Caching, TTL, and Negative Answers Reading Guide for Lab 06

This guide helps you read the RFC sections that matter for DNS Lab 06. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、DNS Lab 06 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 1035: Domain Names - Implementation and Specification](https://www.rfc-editor.org/rfc/rfc1035)
- [RFC 2308: Negative Caching of DNS Queries (DNS NCACHE)](https://www.rfc-editor.org/rfc/rfc2308)
- [RFC 8499: DNS Terminology](https://www.rfc-editor.org/rfc/rfc8499)

## Reading Goal

For this lab, read caching as a time-bounded copy of an answer, where the authoritative zone — not the resolver — sets the clock.

日本語: このLabでは、cache を「時間制限つきの答えのコピー」として読みます。時計を決めるのは resolver ではなく authoritative zone だ、という点を意識します。

Start with these ideas:

- Every resource record carries a TTL: how long it may be cached.
- A resolver caches answers and serves them until the TTL runs out.
- A missing name produces a negative answer, which is also cached.
- Negative answers carry an SOA record; its minimum bounds the negative cache.

## Lab #6 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 1035 | 3.2.1 | resource record の構造と TTL フィールドの位置 |
| 2 | RFC 1035 | 4.1.3 | 応答中の各 RR に TTL が付くこと |
| 3 | RFC 1035 | 7.4 | resolver が答えを cache し、TTL で捨てる |
| 4 | RFC 2308 | 1-3 | negative answer、NXDOMAIN と NODATA の区別 |
| 5 | RFC 2308 | 5 | SOA minimum が negative cache の TTL を決める |

## TTL は誰のものか

よくある誤解は「TTL は resolver が決める」というもの。違う。

- TTL を付けるのは authoritative zone(このLabなら `auth`)。
- resolver は受け取った TTL からカウントダウンし、`0` で捨てるだけ。
- client が見る TTL は「cache に入ってからの残り秒数」。

Lab 06 では `www`(60)と `stable`(3600)で TTL を変え、同じ resolver でもレコードごとに cache 寿命が違うことを見せる。

## Positive Cache

RFC 1035 7.4 が positive caching の根拠。

resolver は解決した RRset を、その TTL の間 cache する。同じ質問が来たら、上流に問い直さずに cache から返す。だから:

- 2回目は速い(`Query time` が小さい)。
- 見える TTL が減る。
- TTL が切れると、次の query で再解決され、TTL がリセットされる。

## Negative Cache

RFC 2308 が negative caching を定める。中心は2種類の「答えが無い」応答。

| 種類 | 意味 | 例 |
|---|---|---|
| NXDOMAIN | 名前そのものが存在しない | `missing.example.lab`(このLab) |
| NODATA | 名前はあるが、その型が無い | `www.example.lab` の AAAA を聞く、など |

どちらも `ANSWER` は空で、`AUTHORITY` にゾーンの **SOA** が入る。resolver はこの SOA を見て、否定応答をどれだけキャッシュしてよいかを決める。

## SOA と Negative TTL

SOA レコードの末尾フィールドが **minimum**。RFC 2308 では、これが negative cache の TTL の上限になる(正確には SOA の TTL と minimum の小さい方)。

```text
example.lab. 300 IN SOA ns.example.lab. admin.example.lab. (
    1 3600 900 604800 300 )
                       ^^^  <- minimum = negative cache TTL
```

Lab 06 では minimum を `300` にしてあるので、`missing.example.lab` の NXDOMAIN は最大 300 秒キャッシュされる。存在しない名前への連打が、毎回 authoritative まで届かないようにするための仕組み。

## Message から読む

Lab の `dig` 出力を RFC の用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `status: NOERROR` + ANSWER あり | positive answer |
| `status: NXDOMAIN` + AUTHORITY に SOA | 名前が無い(negative) |
| `status: NOERROR` + ANSWER 空 + SOA | NODATA(型が無い、negative) |
| 各 RR の2番目のフィールド | TTL(残り秒数) |

## Lab 05 との違い

- Lab 05 は「答えをどう見つけるか」(委任の連鎖)。
- Lab 06 は「答えをどれだけ持つか」「答えが無いときどうするか」(cache と TTL)。
- 同じ階層を使い回すのは、解決の仕組みではなく cache の挙動に集中するため。

## よくある誤解

- TTL を決めるのは resolver ではなく authoritative zone。
- 2回同じ秒内に聞くと TTL 差が見えない。数秒空ける。
- NXDOMAIN(名前が無い)と NODATA(型が無い)は別物。
- negative answer に SOA が付くのは、negative cache の寿命を伝えるため。
- short TTL は更新が速いが問い合わせが増える。TTL は鮮度と負荷のトレードオフ。

## 次の Lab につながる問い

- ここまでで DNS の名前解決と cache を見た。次はその名前で得た IP へ、実際に接続を張る。
- TCP はどうやって接続を確立し、切断するのか(SYN / SYN-ACK / ACK / FIN)。

これは Lab 07(TCP handshake と teardown)で扱う。
