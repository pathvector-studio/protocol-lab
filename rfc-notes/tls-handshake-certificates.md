# TLS Handshake and Certificates Reading Guide for Lab 09

This guide helps you read the RFC sections that matter for TLS Lab 09. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、TLS Lab 09 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 8446: The Transport Layer Security (TLS) Protocol Version 1.3](https://www.rfc-editor.org/rfc/rfc8446)
- [RFC 6066: TLS Extensions (Server Name Indication)](https://www.rfc-editor.org/rfc/rfc6066)
- [RFC 7301: TLS Application-Layer Protocol Negotiation (ALPN)](https://www.rfc-editor.org/rfc/rfc7301)

## Reading Goal

For this lab, read the TLS 1.3 handshake as a short negotiation, and pay attention to where the cleartext ends.

日本語: このLabでは、TLS 1.3 の handshake を「短いネゴシエーション」として読み、平文がどこで終わるかに注目します。

Start with these ideas:

- TLS sits on top of TCP and below the application (HTTP).
- The handshake agrees on a cipher, keys, the server's identity, and the application protocol.
- ClientHello and ServerHello are sent before keys exist, so they are cleartext.
- In TLS 1.3, everything after ServerHello (including the certificate) is encrypted.

## Lab #9 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 8446 | 2 | 1-RTT handshake の全体の流れ |
| 2 | RFC 8446 | 4.1.2 | ClientHello(cipher suites、extensions、key share) |
| 3 | RFC 8446 | 4.1.3 | ServerHello(選ばれた cipher、key share) |
| 4 | RFC 6066 | 3 | SNI(server_name)extension |
| 5 | RFC 7301 | 3 | ALPN extension |
| 6 | RFC 8446 | 4.4.2 | Certificate message(1.3 では暗号化) |

## TLS の位置

TLS は層の間に挟まる。

```text
HTTP           <- application
TLS            <- encryption + server authentication  (このLab)
TCP            <- reliable byte stream  (Lab 07/08)
IP
```

だから「TLS の handshake」は、TCP の 3-way handshake が終わった後、HTTP のリクエストが飛ぶ前に起きる。

## Cleartext はどこまでか

TLS 1.3 の肝は「鍵が導出される瞬間」。

1. ClientHello: client が cipher 候補、extensions(SNI、ALPN offer)、key share を送る。**平文**。
2. ServerHello: server が選んだ cipher と key share を返す。**平文**。
3. この直後、両者は共有鍵を導出する。
4. 以降(EncryptedExtensions、Certificate、CertificateVerify、Finished)は**暗号化**。

だから on-path の観測者に見えるのは 1 と 2 まで。証明書(3 以降)は見えない。

TLS 1.2 では証明書が平文だったので、この点が 1.3 の大きな違い。

## SNI(Server Name Indication)

RFC 6066 3。client が「どのサイト宛てか」を ClientHello に平文で入れる。

- 目的: 1つの IP で複数の証明書を出す server が、鍵が決まる前に正しい証明書を選べるようにする。
- 平文である理由: 証明書選択が handshake の最初に必要だから。
- SNI も隠したい場合は ECH(Encrypted Client Hello)を使うが、既定では無効。このLabでは SNI は見える。

Lab では `-servername www.example.lab` が SNI に入り、capture の ClientHello から読める。

## ALPN(Application-Layer Protocol Negotiation)

RFC 7301 3。上位プロトコル(`h2` / `http/1.1` など)を handshake の中で決める。

- client が候補リストを offer(ClientHello の extension)。
- server が1つ選んで返す(1.3 では EncryptedExtensions の中)。
- 別のネゴシエーション往復を足さずに、TLS の中で決まる。

Lab では client が `h2,http/1.1` を offer し、server が `h2` を選ぶ。

## 証明書と検証

- 証明書は server の identity(名前と公開鍵)を、CA の署名付きで示す。
- client は trust store を使って署名の連鎖を検証する。
- このLabは自己署名なので検証は失敗扱い(`Verify return code: 18`)。公開 CA なら 0。
- CN/SAN は証明書側の名前。SNI は client 側の希望。両者が一致するかも検証の一部。

## Lab 07/08 とのつながり

- Lab 07/08 は TCP そのもの(接続と loss 回復)。
- Lab 09 はその TCP の上に乗る TLS の handshake。
- 次の Lab 10 では、この上で実際に HTTP のやり取りを見る。

## よくある誤解

- SNI(client の希望)と証明書 CN/SAN(server の返答)は別物。
- TLS 1.3 では証明書は平文で見えない(1.2 では見えた)。
- `Verify return code: 18` は自己署名のため。バグではない。
- ALPN は TLS の中で決まる(HTTP より前)。
- SNI は既定で平文。隠すには ECH が要る。

## 次の Lab につながる問い

- TLS で `h2` に合意した後、実際の HTTP リクエスト/レスポンスはどう見えるのか。
- method、header、status code、cache header はどう並ぶのか。

これは Lab 10(HTTP request/response/cache)で扱う。
