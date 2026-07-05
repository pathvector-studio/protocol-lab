# End-to-End Web Request Reading Guide for Lab 12

This guide helps you tie together the RFCs from Labs 05-11 for the capstone. It is meant to be used alongside those RFCs, not instead of them.

日本語: この guide は、Lab 05-11 の RFC を「1つの web request の順番」という視点でつなぎ直すためのものです。

## Reading Goal

For this lab, read the whole stack as a chain: each layer's output feeds the next.

日本語: このLabでは、スタック全体を「連鎖」として読みます。各層の出力が次の層の入力になる、という流れを意識します。

The layers, in order:

- DNS: name → address.
- TCP: address → reliable byte stream.
- TLS: byte stream → encrypted, authenticated stream.
- HTTP: encrypted stream → request/response semantics.

## Lab #12 で読み返す場所

新しい RFC は増やさない。順番の視点で読み返す。

| 順 | 層 | RFC | 見直すポイント |
|---|---|---|---|
| 1 | DNS | RFC 1034 §4-5, 1035 §4 | 名前解決の結果としてアドレスが得られる |
| 2 | TCP | RFC 9293 §3.5 | そのアドレスへ handshake で接続する |
| 3 | TLS | RFC 8446 §2, 6066 §3, 7301 §3 | SNI と ALPN、暗号化の境界 |
| 4 | HTTP | RFC 9110 §3, 9113 §5 | 暗号化ストリーム上の request/response |

## 各層が「次」に渡すもの

連鎖の要点は、境界で何が渡るか。

| 層 | 入力 | 出力(= 次の入力) |
|---|---|---|
| DNS | 名前 `www.example.lab` | アドレス `10.0.2.2` |
| TCP | アドレス + ポート | 確立した接続(バイトストリーム) |
| TLS | バイトストリーム | 暗号化・認証されたストリーム |
| HTTP | 暗号化ストリーム | ステータス + 本文 |

DNS が返すアドレスがなければ TCP は宛先を持てない。TCP の接続がなければ TLS は載る先がない。TLS のストリームがなければ HTTP は安全に流せない。

## 関心の分離(Separation of Concerns)

各層は1つのことだけを担当する。

- DNS: 名前をアドレスに変えることだけ。運び方は知らない。
- TCP: バイトを順序どおり確実に届けることだけ。中身の意味は知らない。
- TLS: 暗号化と相手の認証だけ。何のデータかは知らない。
- HTTP: method / status / header の意味だけ。どう運ばれたかは知らない。

この分離のおかげで、各層を差し替えられる。TCP を QUIC に(Lab 11)、HTTP/1.1 を HTTP/2 に、といった進化が、他の層を壊さずにできる。

## どこで何が見えるか

Lab 12 では capture を2つに分ける。

- eth1(dns 側): DNS の A query と応答(平文)。
- eth2(web 側): TCP handshake、TLS の ClientHello(平文)、以降は暗号化。

つまり「経路上の観測者に見えるもの」は、DNS の名前、宛先アドレス、TLS の SNI まで。HTTP の中身は暗号化されて見えない(Lab 09 の境界)。

## Lab 05-11 の対応

| Lab | 層 | このLabでの役割 |
|---|---|---|
| 05-06 | DNS | 名前をアドレスに |
| 07-08 | TCP | 接続と信頼性 |
| 09 | TLS | 暗号化と認証、SNI/ALPN |
| 10 | HTTP | request/response |
| 11 | HTTP/2, QUIC | 多重化と transport の違い |

Lab 12 はこれらを1つの `curl` で束ねたもの。

## よくある誤解

- 層の順番は DNS → TCP → TLS → HTTP。TLS は TCP の後、HTTP の前。
- DNS の宛先(resolver)と web の宛先は別ノード。
- 経路上で見えるのは SNI まで。HTTP 本文は暗号化される。
- `curl` 1コマンドが、内部でこの全連鎖を順に実行している。
- 各層は独立。だから1つの層(例: HTTP/2 → HTTP/3)を差し替えても全体は動く。

## ここまでの到達点

12 の Lab を通じて、RFC の一部を読み、小さな実験を動かし、ログや packet を観察し、起きたことをプロトコルの言葉で説明できるようになった。1つの web request を、名前解決から暗号化された HTTP 応答まで、層ごとに指させるのがゴール。
