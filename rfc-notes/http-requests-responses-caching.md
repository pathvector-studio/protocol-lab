# HTTP Requests, Responses, and Caching Reading Guide for Lab 10

This guide helps you read the RFC sections that matter for HTTP Lab 10. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、HTTP Lab 10 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs (the 2022 HTTP core):

- [RFC 9110: HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110)
- [RFC 9111: HTTP Caching](https://www.rfc-editor.org/rfc/rfc9111)
- [RFC 9112: HTTP/1.1](https://www.rfc-editor.org/rfc/rfc9112)

これらは古い RFC 7230-7235 を置き換えたもの。semantics(9110)と、その version 固有の書き方(9112 = HTTP/1.1)が分かれているのがポイント。

## Reading Goal

For this lab, read HTTP as semantics (methods, status, headers) that are independent of the transport underneath.

日本語: このLabでは、HTTP を「下の transport とは独立した semantics(method・status・header)」として読みます。

Start with these ideas:

- HTTP transfers representations of resources via request/response messages.
- A message is a start line, headers, a blank line, and an optional body.
- Methods say what to do; status codes say what happened.
- Caching reuses a representation for a while, and revalidates it with conditional requests.

## Lab #10 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 9112 | 2-3 | HTTP/1.1 の message 構文(request line / status line / headers) |
| 2 | RFC 9110 | 9 | method の定義(GET / HEAD) |
| 3 | RFC 9110 | 15 | status code の分類と 200 / 304 / 404 |
| 4 | RFC 9111 | 5.2 | `Cache-Control` |
| 5 | RFC 9111 | 4.3 | conditional request と 304(ETag / If-None-Match) |

## Message の形

RFC 9112 2-3。1つの message は決まった形をしている。

```text
<start line>            request line か status line
<header>: <value>       0 個以上
<header>: <value>
                        空行(ヘッダの終わり)
<body>                  任意
```

- request line: `GET / HTTP/1.1`(method、target、version)。
- status line: `HTTP/1.1 200 OK`(version、code、reason)。
- header はメタデータ。body は representation の中身。

Lab の `curl -v` は、送った行を `>`、受けた行を `<` で示す。

## Method: GET と HEAD

RFC 9110 9。

- **GET**: リソースの representation を取得する。安全(サーバの状態を変えない)。
- **HEAD**: GET と同じヘッダを返すが body は返さない。存在確認・サイズ確認・キャッシュ検証に使える。

このLabでは、GET が body 付き、HEAD が body なしで同じヘッダ、という対比を見る。

## Status Code

RFC 9110 15。先頭の数字でグループが分かる。

| 範囲 | 意味 | Lab の例 |
|---|---|---|
| 2xx | 成功 | 200 OK |
| 3xx | さらなるアクション/条件 | 304 Not Modified |
| 4xx | クライアント側の問題 | 404 Not Found |
| 5xx | サーバ側の問題 | (このLabでは出さない) |

`304` が 3xx にいるのがポイント。エラーではなく「変わっていない」という最適化。

## Caching と Conditional Request

RFC 9111 が caching の中心。2つの道具を分けて読む。

- **freshness(鮮度)**: `Cache-Control: max-age=60` は「60 秒はそのまま再利用してよい」。この間はサーバに聞かなくてよい。
- **validation(検証)**: 鮮度が切れたら、`ETag` を使って「まだ同じか?」を確かめる。クライアントは `If-None-Match: <etag>` を付けて聞く。

サーバの反応:

- representation が同じ → `304 Not Modified`(body なし)。キャッシュはコピーを再利用し、鮮度を更新する。
- 変わっている → `200 OK` と新しい body、新しい ETag。

これで「変わっていないものを再送しない」を実現する。ブラウザや CDN が日常的に使う仕組み。

## Transport からの独立

- HTTP の semantics は、下が TCP でも(Lab 07/08)、TLS 越しでも(Lab 09)、HTTP/2 でも(Lab 11)同じ。
- 変わるのは「どう運ぶか(framing、多重化、暗号化)」であって、「何を意味するか(method、status、header)」ではない。
- このLabは平文 HTTP/1.1 なので、semantics を capture で直接読める。

## よくある誤解

- HEAD は body を返さない(ヘッダのみ)。
- 304 はエラーではなく最適化(Not Modified)。
- `Cache-Control`(鮮度)と `ETag`(検証)は役割が別。
- curl 自身はキャッシュしない。見せているのは cache の仕組み。
- HTTP/1.1 では `Host` header が必須(1 IP で複数サイトを見分ける)。

## 次の Lab につながる問い

- HTTP/1.1 は1接続で1つずつ処理する。複数のリクエストを同時に流すには?
- HTTP/2 の stream と multiplexing、そして QUIC の上での違いは?

これは Lab 11(HTTP/2 と QUIC)で扱う。
