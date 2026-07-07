# Encrypted DNS (DoT / DoH) Reading Guide for Lab 14

This guide helps you read the RFC sections that matter for DNS Lab 14. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、DNS Lab 14 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 7858: DNS over TLS (DoT)](https://www.rfc-editor.org/rfc/rfc7858)
- [RFC 8484: DNS Queries over HTTPS (DoH)](https://www.rfc-editor.org/rfc/rfc8484)
- [RFC 9499: DNS Terminology](https://www.rfc-editor.org/rfc/rfc9499)
- [RFC 8446: TLS 1.3](https://www.rfc-editor.org/rfc/rfc8446)

## Reading Goal

For this lab, read DoT and DoH as *the same DNS messages wrapped in TLS*. The DNS semantics do not change; only the transport does, and that transport hides the query from the path.

日本語: このLabでは、DoT/DoH を「同じ DNS メッセージを TLS で包んだもの」として読みます。DNS の意味は変わらず、変わるのは transport だけ。その transport が query を経路から隠します。

Start with these ideas:

- Do53 (plain DNS on port 53) sends the query name in cleartext.
- DoT (port 853) and DoH (port 443, `/dns-query`) put the same query inside TLS.
- Encryption hides the query and answer, but not the fact that you are talking to a resolver.

## Lab #14 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 7858 | 3 | DoT: ポート 853、TLS を張って DNS を流す |
| 2 | RFC 8484 | 4 | DoH: `/dns-query`、`application/dns-message`、GET/POST |
| 3 | RFC 8484 | 5 | DoH の HTTP としての振る舞い(キャッシュ、メソッド) |
| 4 | RFC 9499 | 6 | Do53 / DoT / DoH の用語整理 |
| 5 | RFC 8446 | 2 | 下地の TLS 1.3 handshake(Lab 09 の復習) |

## 完全性と秘匿性は別物

Lab 13(DNSSEC)と Lab 14(DoT/DoH)は、よく混同されるが目的が違う。

| 仕組み | 守るもの | どうやって | 見えなくなるもの |
|---|---|---|---|
| DNSSEC | 完全性・真正性 | 署名(RRSIG)を検証 | (何も隠さない。中身は平文) |
| DoT / DoH | 秘匿性 | TLS で暗号化 | query 名・答えの中身 |

- DNSSEC は「答えが本物か」を保証するが、query も答えも**平文のまま**流れる。
- DoT/DoH は「経路上の誰にも中身を読ませない」が、答えの真正性そのものは保証しない。
- 本当に堅くするには**両方**要る(正しくて、かつ覗かれない)。

## DoT — DNS over TLS(RFC 7858)

- 専用ポート **853**。client は server と TLS を張り、その中で通常の DNS メッセージ(binary wire format)をやり取りする。
- 「これは DNS だ」と分かりやすい(853 番で判別できる)。裏を返すと、853 をブロックすれば潰せる。
- TLS の張り方・証明書検証は Lab 09 と同じ。実運用では resolver の証明書を検証する(strict mode)。

## DoH — DNS over HTTPS(RFC 8484)

- **443** の HTTPS に載せる。既定パスは **`/dns-query`**。
- メッセージは `application/dns-message`(DoT と同じ wire format)。
  - POST: body に DNS メッセージ。
  - GET: `?dns=<base64url>` で渡す(HTTP キャッシュに乗せやすい)。
- 見た目が普通の HTTPS と区別しにくいので、ネットワーク的にブロックしにくい。ブラウザが採用したのはこの性質が大きい。

## 何が隠れて、何が隠れないか

RFC 7858/8484 と TLS(RFC 8446)から読み取る。

| 項目 | Do53 | DoT / DoH |
|---|---|---|
| query 名・答え | 見える | **隠れる**(TLS の中) |
| 通信相手(resolver の IP) | 見える | 見える |
| 「暗号化 DNS を使っている」事実 | — | 見える(853/443 への TLS) |
| SNI(接続先ホスト名) | — | 既定では見える(隠すのは ECH) |

- 暗号化 DNS は**盗聴(on-path observer)からの秘匿**が主目的。相手サーバや「使っている事実」までは隠さない。
- SNI が平文なので、DoH で公開 resolver の特定ホストを指す場合などに宛先名が漏れうる。これを塞ぐのが Encrypted Client Hello(ECH、このLabの範囲外)。

## Message から読む

Lab の capture を RFC の用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| port 53 に `A? name` が平文 | Do53、query 名が読める |
| port 853/443 に TLS handshake(ClientHello=1) | DoT/DoH、以降は暗号化 |
| capture に query 名が出てこない | TLS の中に隠れている |
| dig `+tls` / `+https` | client 側で DoT / DoH を使う指定 |

## よくある誤解

- 「暗号化 DNS = DNSSEC」ではない。秘匿と完全性は別。
- 暗号化してもすべてが隠れるわけではない(相手・SNI は見えうる)。
- DoT と DoH の違いはポートと「HTTP に載るか」。中身の DNS メッセージは同じ。
- `dig +tls` は既定で証明書を検証しないことが多い。実運用は strict に。
- DoH は「ただの HTTPS」ではなく、中身は DNS。運用上ブロックしにくいのが要点。

## 前後の Lab とのつながり

- Lab 09 の TLS が、そのまま DoT/DoH の土台になっている。
- Lab 13(DNSSEC)は完全性、Lab 14 は秘匿性。両輪。
- この先、SNI まで隠す ECH、DNS over QUIC(DoQ)、証明書を DNS に載せる DANE(Lab 13 の DNSSEC が前提)へと広がる。
