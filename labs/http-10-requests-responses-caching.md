# HTTP Lab #10: One Exchange, Read in the Clear

Expected time: 45 to 60 minutes  
日本語: 想定時間 45〜60分

Reading guide: [`../rfc-notes/http-requests-responses-caching.md`](../rfc-notes/http-requests-responses-caching.md)

Prerequisite: [TCP Lab 07: One Connection, From SYN to FIN](tcp-07-handshake-teardown.md)

## Goal

TCP carried bytes; TLS could wrap them. This lab looks at the bytes themselves: one HTTP/1.1 request and its response, in cleartext, so you can name every line.

You will send four requests and read each result:

- `GET /` → **200 OK** with `Cache-Control` and `ETag`,
- `HEAD /` → **200** headers only, no body,
- `GET /` with `If-None-Match` → **304 Not Modified** (the cached copy is still fresh),
- `GET /missing` → **404 Not Found**.

日本語: TCP はバイトを運び、TLS はそれを包めました。この Lab はバイトそのもの、つまり1つの HTTP/1.1 リクエストとレスポンスを平文で見て、各行に名前を付けられるようにします。4種類のリクエストを送り、`GET /`(200 + cache header)、`HEAD /`(ヘッダのみ)、条件付き `GET`(304)、`GET /missing`(404)を読みます。

By the end, you should be able to label this exchange:

```text
> GET / HTTP/1.1            <- request line: method, target, version
> Host: 10.0.0.2:8080       <- request header
>
< HTTP/1.1 200 OK           <- status line
< Content-Type: text/plain; charset=utf-8
< Content-Length: 40
< Cache-Control: max-age=60 <- how long a cache may reuse this
< ETag: "v1-abc123"         <- a validator for conditional requests
<
Hello from the Protocol Lab HTTP server.
```

## What You Will Learn

理解したいこと:

- The shape of an HTTP message: start line, headers, blank line, body.
- What methods GET and HEAD do, and how HEAD differs from GET.
- How status codes group into 2xx / 3xx / 4xx and what 200, 304, 404 mean.
- What `Cache-Control` and `ETag` are for.
- How a conditional request (`If-None-Match`) produces `304 Not Modified` and saves a body.

This lab does not cover:

- HTTPS/TLS on top of HTTP (that was Lab 09).
- HTTP/2 framing and multiplexing (that is Lab 11).
- A full cache implementation, `Vary`, or revalidation edge cases.
- Cookies, auth, or redirects in depth.

## RFCで読む場所

HTTP の現行仕様は RFC 9110-9112(2022)。

| RFC | 章 | 読むポイント |
|---|---|---|
| RFC 9110 | 3, 6 | resource、representation、message の考え方 |
| RFC 9110 | 9 | methods(GET / HEAD の定義) |
| RFC 9110 | 15 | status codes(200 / 304 / 404 の意味) |
| RFC 9111 | 5.2 | `Cache-Control` ディレクティブ |
| RFC 9111 | 4.3 | validation と conditional request(`ETag` / `If-None-Match` / 304) |
| RFC 9112 | 2-3 | HTTP/1.1 の message 構文(start line、header、body) |

## 実験の全体像

Lab 07 と同じ2ノード。server は小さな Python HTTP サーバ。TLS は使わず、平文で観察する。

```text
client (10.0.0.1) ------ eth1/eth1 ------ server (10.0.0.2:8080)
                                          python3 app.py
                                          GET /  -> 200 (+Cache-Control, ETag)
                                          If-None-Match -> 304
                                          /missing -> 404
```

両ノードとも `nicolaka/netshoot`(`curl`、`python3`、`tcpdump` 同梱)。追加イメージは不要。

## 必要なもの

推奨環境:

- Linux / WSL2 / Linux VM
- Docker
- containerlab

使用イメージ:

- `nicolaka/netshoot:latest`

## 実行手順

```bash
./scripts/labctl.sh run http-10
```

`labctl.sh run http-10` は、deploy、HTTP サーバ起動、4種の curl 実行、status/header/cache の確認、後片付けまで行う。

### 1. 作業ディレクトリへ移動する

```bash
cd protocol-lab/examples/http-10
```

### 2. server を読んでから起動する

```bash
cat server/app.py
sudo containerlab deploy -t http-10.clab.yml
docker exec -d clab-http-10-server python3 /app/app.py
```

`app.py` は、`GET /` に 200 と cache header を返し、`If-None-Match` が一致すれば 304、`/missing` には 404 を返す小さなサーバ。

### 3. GET / を送る(200 と cache header)

```bash
docker exec clab-http-10-client curl -v http://10.0.0.2:8080/
```

見るポイント:

```text
> GET / HTTP/1.1
> Host: 10.0.0.2:8080
< HTTP/1.1 200 OK
< Content-Type: text/plain; charset=utf-8
< Content-Length: 40
< Cache-Control: max-age=60
< ETag: "v1-abc123"
```

`>` が送ったリクエスト、`<` が返ってきたレスポンス(curl の表記)。

### 4. HEAD / を送る(ヘッダのみ)

```bash
docker exec clab-http-10-client curl -v -I http://10.0.0.2:8080/
```

`HEAD` は `GET` と同じヘッダを返すが、body は返さない。`Content-Length` は付くが本文は空。

### 5. 条件付き GET を送る(304)

さっき見た `ETag` を `If-None-Match` に入れて、もう一度 `GET`。

```bash
docker exec clab-http-10-client curl -v -H 'If-None-Match: "v1-abc123"' http://10.0.0.2:8080/
```

見るポイント:

```text
< HTTP/1.1 304 Not Modified
< ETag: "v1-abc123"
< Cache-Control: max-age=60
```

`304` は「あなたが持っているコピーはまだ新しい。body は送らない」。これでネットワークとサーバの負荷を減らせる。

### 6. 存在しないパスを叩く(404)

```bash
docker exec clab-http-10-client curl -v http://10.0.0.2:8080/missing
```

```text
< HTTP/1.1 404 Not Found
```

### 7. 平文であることを capture で確かめる

```bash
docker exec clab-http-10-client sh -c \
  "tcpdump -i eth1 -A -s0 'tcp port 8080' &  sleep 1;  curl -s http://10.0.0.2:8080/ >/dev/null;  sleep 1;  pkill tcpdump"
```

`-A` でペイロードを ASCII 表示すると、`GET / HTTP/1.1` や `HTTP/1.1 200 OK` がそのまま読める。TLS がないので、経路上の観測者に中身が見える(Lab 09 との対比)。

## 期待出力

- `GET /`: `HTTP/1.1 200 OK`、`Cache-Control: max-age=60`、`ETag: "v1-abc123"`。
- `HEAD /`: 同じヘッダ、body なし。
- 条件付き `GET`: `HTTP/1.1 304 Not Modified`、body なし。
- `GET /missing`: `HTTP/1.1 404 Not Found`。
- capture: リクエスト行・ステータス行・ヘッダが平文で読める。

## なぜそう動くのか

HTTP は「リソースの representation を、request/response でやり取りする」プロトコル。1つの message は、start line(request line か status line)、header 群、空行、body の順。

- **method** は「何をしたいか」。`GET` は取得、`HEAD` は「ヘッダだけ欲しい(本文は要らない)」。だから HEAD は転送量を節約して、存在確認やサイズ確認に使える。
- **status code** は結果の分類。`2xx` 成功、`3xx` さらなるアクション、`4xx` クライアント側の問題。`200` は取得成功、`404` は無い、`304` は「変わっていない」。
- **cache header**: `Cache-Control: max-age=60` は「60 秒はそのまま再利用してよい」。`ETag` はその representation の識別子(validator)。
- **conditional request**: クライアント(やキャッシュ)は次回、`If-None-Match: <etag>` を付けて聞く。サーバは同じなら `304`(body なし)を返す。変わっていれば `200` と新しい body。これで「変わっていないものを再送しない」を実現する。

要点は、HTTP のセマンティクス(method / status / header)が、下の TCP・TLS とは独立した層として読めること。

## 詰まりやすい点

- **HEAD が body を返すと思う**。HEAD はヘッダのみ。`Content-Length` は付くが本文はない。
- **304 を「エラー」と読む**。304 は成功的な最適化。「変わっていないから送らない」。
- **`Cache-Control` と `ETag` の役割を混同する**。`max-age` は「どれだけ再利用してよいか(鮮度)」、`ETag` は「同じかどうかを確かめる印(validation)」。
- **curl が自分でキャッシュすると思う**。curl はキャッシュしない。ここで見せているのは cache の**仕組み**(header と 304)。ブラウザや CDN がこれを使う。
- **平文であること**。この Lab は HTTP(暗号化なし)。だから capture で中身が読める。実運用は HTTPS。
- **`Host` header**。HTTP/1.1 では必須。1つの IP で複数サイトを見分ける(SNI の HTTP 版のような役割)。

## 後片付け

```bash
sudo containerlab destroy -t http-10.clab.yml --cleanup
```

`labctl.sh run http-10` を使った場合は、スクリプトが最後に destroy する。

## 確認問題

1. HTTP message の4つの構成要素は何か(start line 以降)。
2. GET と HEAD は何が違うか。HEAD は何に使えるか。
3. 200 / 304 / 404 はそれぞれ何を意味するか。どのグループ(2xx/3xx/4xx)か。
4. `Cache-Control: max-age=60` と `ETag` は、それぞれ何のためにあるか。
5. 条件付き `GET`(`If-None-Match`)はどんなときに `304` を返すか。何を節約できるか。
6. この Lab の通信はなぜ capture で読めるのか。Lab 09 とどう違うか。

## References

- [RFC 9110: HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110)
- [RFC 9111: HTTP Caching](https://www.rfc-editor.org/rfc/rfc9111)
- [RFC 9112: HTTP/1.1](https://www.rfc-editor.org/rfc/rfc9112)
- [RFC 5737: IPv4 Address Blocks Reserved for Documentation](https://www.rfc-editor.org/rfc/rfc5737)
- [curl manual page](https://curl.se/docs/manpage.html)
