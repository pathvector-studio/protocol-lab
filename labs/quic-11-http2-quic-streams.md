# Lab #11: HTTP/2 Streams and the Jump to QUIC

Expected time: 55 to 70 minutes  
日本語: 想定時間 55〜70分

Reading guide: [`../rfc-notes/http2-quic-streams.md`](../rfc-notes/http2-quic-streams.md)

Prerequisite: [HTTP Lab 10: One Exchange, Read in the Clear](http-10-requests-responses-caching.md), [TLS Lab 09: What Is Visible Before Encryption](tls-09-handshake-certificates.md)

## Goal

HTTP/1.1 (Lab 10) does one request at a time per connection. HTTP/2 multiplexes many requests as **streams** over one TCP connection. HTTP/3 moves those streams onto **QUIC**, which runs over UDP. This lab shows the difference at a high level.

You will:

- fetch over **HTTP/2** and confirm ALPN negotiated `h2`,
- send several requests at once and see them **multiplexed over one TCP connection**,
- read the **`Alt-Svc: h3`** header the server uses to advertise HTTP/3,
- see that HTTP/3 / QUIC lives on **UDP**, not TCP.

日本語: HTTP/1.1(Lab 10)は1接続で1リクエストずつ。HTTP/2 は多数のリクエストを **stream** として1本の TCP 接続に多重化します。HTTP/3 はその stream を **QUIC**(UDP の上)に移します。この Lab では、その違いを大まかに観察します。HTTP/2 で fetch して ALPN が `h2` になること、複数リクエストが1本の TCP 接続に多重化されること、server が `Alt-Svc: h3` で HTTP/3 を広告すること、そして QUIC が TCP ではなく UDP に乗ることを見ます。

By the end, you should be able to explain this comparison:

| | HTTP/1.1 | HTTP/2 | HTTP/3 |
|---|---|---|---|
| Transport | TCP | TCP | QUIC over UDP |
| Concurrency | 1 request / connection | many streams / 1 connection | many streams / 1 connection |
| Head-of-line blocking | at HTTP layer | at TCP layer | avoided per-stream |
| Advertised by | — | ALPN `h2` | `Alt-Svc: h3` + ALPN `h3` |

## What You Will Learn

理解したいこと:

- What a stream is, and how HTTP/2 multiplexes streams over one connection.
- Why one TCP connection can still stall all streams (TCP head-of-line blocking).
- How QUIC puts streams directly on UDP and avoids that cross-stream stall.
- How ALPN and `Alt-Svc` let a client discover and pick a version.

This lab does not cover:

- HTTP/2 flow control, priorities, or HPACK header compression internals.
- QUIC's congestion control or loss recovery details.
- 0-RTT / connection migration.
- Tuning for performance.

## RFCで読む場所

| RFC | 章 | 読むポイント |
|---|---|---|
| RFC 9113 | 5 | HTTP/2 の stream(状態、多重化) |
| RFC 9113 | 4 | frame(stream に分割して運ぶ単位) |
| RFC 9114 | 2 | HTTP/3 の stream mapping(QUIC stream への対応) |
| RFC 9000 | 2 | QUIC の stream(独立配送) |
| RFC 7301 | 3 | ALPN(h2 / h3 の選択) |
| RFC 9110 | 3.9 | `Alt-Svc` の考え方(alternative service の広告) |

## 実験の全体像

Lab 07 以来の2ノード。server は Caddy(HTTP/1.1・HTTP/2・HTTP/3 を1つの binary で提供)。client は netshoot の curl。

```text
client (10.0.0.1) ------ eth1/eth1 ------ server (10.0.0.2:443 tcp+udp)
                                          Caddy
                                          h1 / h2 (TCP) / h3 (QUIC/UDP)
```

server の応答本文は、その時使われた protocol を書き返す(`Hello over HTTP/2.0 ...`)。だから、どの transport で届いたかが本文で分かる。

```mermaid
flowchart TB
  subgraph h2["HTTP/2 over TCP"]
    t["1 TCP connection"] --- s1["stream 1"]
    t --- s3["stream 3"]
    t --- s5["stream 5"]
    note2["1つの TCP が詰まると<br/>全 stream が待つ<br/>(TCP head-of-line blocking)"]
  end
  subgraph h3["HTTP/3 over QUIC/UDP"]
    q["1 QUIC connection (UDP)"] --- q1["stream 0"]
    q --- q2["stream 4"]
    q --- q3["stream 8"]
    note3["stream ごとに独立配送<br/>1つの loss が他を止めない"]
  end
```

server イメージは `./Dockerfile`(`caddy:2` に `iproute2` を足したもの)から `run.sh` がビルドする。client は `nicolaka/netshoot`。

## 必要なもの

推奨環境:

- Linux / WSL2 / Linux VM
- Docker
- containerlab

使用イメージ:

- `protocol-lab/caddy:2`(`examples/quic-11/Dockerfile` からローカルビルド)
- `nicolaka/netshoot:latest`

HTTP/3 の観察には、client の curl が HTTP/3 対応でビルドされている必要がある。未対応でも、`Alt-Svc` 広告と UDP リスナーで QUIC の存在は確認できる。

## 実行手順

```bash
./scripts/labctl.sh run quic-11
```

`labctl.sh run quic-11` は、caddy イメージのビルド、deploy、HTTP/2 fetch と多重化の capture、`Alt-Svc` の確認、後片付けまで行う。

### 1. 作業ディレクトリへ移動する

```bash
cd protocol-lab/examples/quic-11
```

### 2. ビルドして起動する

```bash
docker build -t protocol-lab/caddy:2 .
sudo containerlab deploy -t quic-11.clab.yml
```

Caddy の internal CA は名前付きサイト(`www.example.lab`)に対して証明書を発行する。そのため client は IP 直打ちではなく、`--resolve www.example.lab:443:10.0.0.2` で名前を IP に固定しつつ、その名前(SNI)で接続する。以下のコマンドはすべてこの `--resolve` を付ける。

### 3. HTTP/2 で1回 fetch する

```bash
docker exec clab-quic-11-client curl -k --resolve www.example.lab:443:10.0.0.2 --http2 -sv https://www.example.lab/one
```

見るポイント:

```text
* ALPN: server accepted h2
* using HTTP/2
< HTTP/2 200
Hello over HTTP/2.0 for /one
```

`-k` は自己署名(Caddy internal CA)を許すため。本文が `HTTP/2.0` と書き返す。

### 4. 複数リクエストを同時に投げて多重化を見る

```bash
docker exec clab-quic-11-client sh -c \
  "curl -k --resolve www.example.lab:443:10.0.0.2 --http2 -sv --parallel \
     https://www.example.lab/a https://www.example.lab/b https://www.example.lab/c 2>&1 | grep -Ei 'multiplex|Connected|HTTP/2'"
```

`--parallel` だけにする(`--parallel-immediate` を付けない)ことで、curl は最初の1本を張ってから残りを同じ接続に多重化する。`--parallel-immediate` を付けると接続を即座に別々に開いてしまい、多重化が見えない。

見るポイント:

- 3つのリクエストが1本の接続に相乗り(`Multiplexed connection found`)。
- 接続は1本(同じ `Connected to`)。

capture で TCP 接続数を数えると、3リクエストでも SYN は1つ(=1接続に多重化)。

```bash
docker exec clab-quic-11-client sh -c \
  "tcpdump -n -r /tmp/quic-11.pcap 'tcp[tcpflags] & tcp-syn != 0 and tcp[tcpflags] & tcp-ack == 0' | wc -l"
```

### 5. HTTP/3 の広告を読む

```bash
docker exec clab-quic-11-client sh -c "curl -k --resolve www.example.lab:443:10.0.0.2 --http2 -sD - -o /dev/null https://www.example.lab/"
```

レスポンスヘッダに:

```text
alt-svc: h3=":443"; ma=2592000
```

これは「同じサービスは h3(HTTP/3)でも `:443`(UDP)で受けられる」という広告。client は次回から QUIC を試せる。

### 6. HTTP/3 を試す(curl が対応していれば)

```bash
docker exec clab-quic-11-client sh -c "curl -V | grep -i HTTP3"
docker exec clab-quic-11-client curl -k --resolve www.example.lab:443:10.0.0.2 --http3 -sv https://www.example.lab/three
```

対応していれば本文は `Hello over HTTP/3.0 ...`。capture では TCP ではなく **UDP/443** のパケット(QUIC)になる。未対応なら、server 側の UDP リスナーで QUIC の待ち受けを確認する。

```bash
docker exec clab-quic-11-server sh -c "ss -uln"
```

## 期待出力

- HTTP/2 fetch: `using HTTP/2`、本文 `HTTP/2.0`。
- 多重化: 3リクエストで SYN 1つ(1 TCP 接続)。stream ID が複数。
- `alt-svc: h3=":443"`。
- (対応時)HTTP/3 fetch: 本文 `HTTP/3.0`、capture は UDP。

## なぜそう動くのか

HTTP/2 と HTTP/3 の狙いは同じ「1接続で多数のやり取りを同時に流す」。違いは、その stream を何の上に乗せるか。

- **HTTP/2 = streams over TCP**: 1本の TCP 接続の中を、frame 単位で分割し、stream 番号で束ねる。多重化で HTTP/1.1 の「1接続1リクエスト」の制約を外す。ただし下は1本の TCP。あるパケットが失われて再送待ちになると、その後ろの**全 stream** が TCP レベルで止まる(TCP head-of-line blocking)。
- **HTTP/3 = streams over QUIC(UDP)**: QUIC は UDP の上に、暗号化・信頼性・stream を自分で実装する。stream ごとに独立して届けられるので、ある stream の loss が他の stream を止めない。だから loss のある経路で有利。
- **discovery**: client は最初 TCP で来て、ALPN で `h2` を選ぶ。server は `Alt-Svc: h3` で「UDP の h3 もあるよ」と教える。client は次回 QUIC を試す。

要点は、**HTTP の意味(method/status/header、Lab 10)は同じまま、運び方(transport と多重化)が変わっている**こと。

## 詰まりやすい点

- **HTTP/2 に TLS は必須(実運用上)**。ブラウザや curl の `h2` は TLS + ALPN 前提。だから Lab 09 の TLS が土台。
- **多重化と並列接続を混同する**。HTTP/1.1 は複数 TCP 接続で並列化した。HTTP/2 は1接続の中の stream で多重化する。
- **TCP head-of-line blocking**。HTTP/2 は HTTP 層の HoL を消したが、TCP 層の HoL は残る。QUIC がそこを解く。
- **QUIC は UDP の上の独自 transport**。ただの UDP 送信ではなく、暗号化・順序・再送・stream を自前で持つ。
- **`-k` が要る理由**。Caddy の internal CA は client の trust store に無いから。実運用は公開 CA。
- **HTTP/3 の観察は client 依存**。curl が HTTP/3 対応でないと `--http3` は使えない。その場合は `Alt-Svc` と UDP リスナーで存在だけ確認する。

## 後片付け

```bash
sudo containerlab destroy -t quic-11.clab.yml --cleanup
```

`labctl.sh run quic-11` を使った場合は、スクリプトが最後に destroy する。

## 確認問題

1. HTTP/2 の stream とは何か。HTTP/1.1 の「1接続1リクエスト」とどう違うか。
2. HTTP/2 で多重化しても残る head-of-line blocking はどの層のものか。QUIC はそれをどう解くか。
3. QUIC はどの transport(TCP / UDP)の上に乗るか。なぜ UDP なのか。
4. `Alt-Svc: h3` は何を伝えるヘッダか。client はそれをどう使うか。
5. HTTP/2 と HTTP/3 で、HTTP の semantics(method/status/header)は変わるか。
6. capture で、HTTP/2 と HTTP/3 のパケットはどう見分けられるか。

## References

- [RFC 9113: HTTP/2](https://www.rfc-editor.org/rfc/rfc9113)
- [RFC 9114: HTTP/3](https://www.rfc-editor.org/rfc/rfc9114)
- [RFC 9000: QUIC: A UDP-Based Multiplexed and Secure Transport](https://www.rfc-editor.org/rfc/rfc9000)
- [RFC 7301: TLS Application-Layer Protocol Negotiation (ALPN)](https://www.rfc-editor.org/rfc/rfc7301)
- [RFC 9110: HTTP Semantics (Alt-Svc)](https://www.rfc-editor.org/rfc/rfc9110)
- [Caddy web server](https://caddyserver.com/docs/)

## 検証済み実行ログ (2026-07-05)

このLabは実機で再現性を確認済みです。

実行環境:

- Ubuntu 26.04 LTS (kernel 7.0.0-27-generic, x86_64)
- Docker 29.1.3
- containerlab 0.77.0
- server: `caddy:2` に iproute2 を足した `protocol-lab/caddy:2`（h1/h2/h3 を :443 で提供、internal CA）
- client: `nicolaka/netshoot:latest`（curl 8.21.0 / nghttp2 1.69.0、**HTTP/3 非対応ビルド**）

`PATH="/tmp/pl-shim:$PATH" ./scripts/labctl.sh run quic-11` で deploy → verify → destroy を実行し、`verification.json` は `"status": "verified"` を返した。

### 環境ドリフト / 設計上の修正（この検証で必要になった）

- **bare `:443` サイトでは internal CA が証明書を発行できない**。Caddyfile のサイトを `:443` から `www.example.lab:443` に変更（サブジェクト名を与える）。ホスト部は SNI/Host のマッチングにだけ効き、bind は wildcard `:443` のままなので lab IP の割当順に依存しない。client は `curl --resolve www.example.lab:443:10.0.0.2` で名前接続する（`examples/quic-11/run.sh` と本文の手順を更新）。
- **多重化の計測**。`--parallel-immediate` を外して素の `--parallel` にし、3リクエストが1本の TCP 接続に相乗りするようにした。さらに、多重化 fetch の直後で capture を止め、後続の fetch を数えないようにした。

### 単一 HTTP/2 fetch（ALPN h2 over TLS）

```text
$ curl -k --resolve www.example.lab:443:10.0.0.2 --http2 -sv https://www.example.lab/one
* ALPN: server accepted h2
*   issuer: CN=Caddy Local Authority - ECC Intermediate
* using HTTP/2
< HTTP/2 200
Hello over HTTP/2.0 for /one
```

本文が `Hello over HTTP/2.0` と、処理したプロトコルを自己申告している。証明書は Caddy internal CA 発行。

### 3リクエストを1本の接続に多重化

```text
$ curl -k --resolve www.example.lab:443:10.0.0.2 --http2 -sv --parallel \
    https://www.example.lab/a https://www.example.lab/b https://www.example.lab/c
* Waiting on connection to negotiate possible multiplexing.
* Multiplexed connection found
< HTTP/2 200
< HTTP/2 200
< HTTP/2 200
Hello over HTTP/2.0 for /a
Hello over HTTP/2.0 for /b
Hello over HTTP/2.0 for /c
```

capture 中の SYN(新規 TCP 接続)を数えると:

```text
[protocol-lab][quic-11] distinct TCP connections opened during the multiplexed fetch: 1 (1 = fully multiplexed)
```

3リクエストでも新規 TCP 接続は **1本**。HTTP/2 は1接続上の複数 stream に多重化する。

### HTTP/3 の広告（Alt-Svc）と QUIC リスナー

```text
$ curl -k --resolve www.example.lab:443:10.0.0.2 --http2 -sD - -o /dev/null https://www.example.lab/
HTTP/2 200
alt-svc: h3=":443"; ma=2592000
```

`alt-svc: h3=":443"` は「同じサービスを h3(HTTP/3, UDP :443)でも受けられる」という広告。

このホストの curl 8.21.0 は HTTP/3 非対応ビルド(`curl -V` に `HTTP3` が出ない)だったので、client からの h3 fetch は行わず、server 側で QUIC の待ち受けを確認した:

```text
$ docker exec clab-quic-11-server ss -uln
State  Recv-Q Send-Q Local Address:Port  Peer Address:Port
UNCONN 0      0                  *:443              *:*
```

server は UDP :443 で QUIC を待ち受けている(h3 エンドポイントは存在する)。client の curl が対応していれば `curl --http3` で `Hello over HTTP/3.0` を UDP/443 上に観測できる。

### Cleanup

```bash
containerlab destroy -t quic-11.clab.yml --cleanup
```
