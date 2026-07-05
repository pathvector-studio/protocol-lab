# TLS Lab #9: What Is Visible Before Encryption

Expected time: 55 to 70 minutes  
日本語: 想定時間 55〜70分

Reading guide: [`../rfc-notes/tls-handshake-certificates.md`](../rfc-notes/tls-handshake-certificates.md)

Prerequisite: [TCP Lab 07: One Connection, From SYN to FIN](tcp-07-handshake-teardown.md)

## Goal

TCP gave us a reliable byte stream. TLS runs on top of it to add encryption and server authentication. This lab opens one TLS 1.3 connection and asks a precise question: **what can an on-path observer see before encryption takes over?**

You will:

- run an `openssl s_server` with a self-signed certificate and ALPN,
- connect with `openssl s_client` using **SNI** (`-servername`),
- read the negotiated **protocol**, **cipher**, **certificate**, and **ALPN**,
- capture the handshake and see that **ClientHello** (with SNI and the ALPN offer) is in the clear, while in TLS 1.3 the **certificate is encrypted**.

日本語: TCP は信頼できるバイトストリームをくれました。TLS はその上で暗号化とサーバ認証を足します。この Lab では TLS 1.3 の接続を1本張り、「暗号化が始まる前に、経路上の観測者には何が見えるのか」を確かめます。`openssl s_server`(自己署名証明書 + ALPN)を立て、`openssl s_client` を SNI 付きで繋ぎ、ネゴシエートされた protocol / cipher / certificate / ALPN を読み、handshake を capture して、ClientHello(SNI と ALPN offer を含む)は平文で見え、TLS 1.3 では certificate が暗号化されていることを観察します。

By the end, you should be able to fill in this table:

| Handshake item | Visible on the wire (TLS 1.3)? | How you saw it |
|---|---|---|
| SNI (`server_name`) | yes, in ClientHello | capture / tshark |
| ALPN offer | yes, in ClientHello | capture / tshark |
| Chosen cipher / version | yes, in ServerHello | capture |
| Server certificate | no (encrypted) | only via `s_client` endpoint |

## What You Will Learn

理解したいこと:

- Where TLS sits: on top of TCP, below the application (HTTP).
- What ClientHello and ServerHello carry, and which parts are cleartext.
- What SNI is and why the server needs it before choosing a certificate.
- What ALPN negotiates (e.g. `h2` vs `http/1.1`).
- Why, in TLS 1.3, the certificate is sent encrypted (unlike TLS 1.2).

This lab does not cover:

- A real CA-signed certificate chain or trust-store validation.
- Client certificates / mutual TLS.
- Encrypted Client Hello (ECH) that also hides SNI.
- The cryptographic details of key exchange.

## RFCで読む場所

| RFC | 章 | 読むポイント |
|---|---|---|
| RFC 8446 | 2 | TLS 1.3 handshake の全体像(1-RTT) |
| RFC 8446 | 4.1.2 | ClientHello の中身 |
| RFC 8446 | 4.1.3 | ServerHello の中身 |
| RFC 8446 | 4.4.2 | Certificate message(1.3 では暗号化される) |
| RFC 6066 | 3 | Server Name Indication(SNI) |
| RFC 7301 | 3 | Application-Layer Protocol Negotiation(ALPN) |
| RFC 5737 | 3 | Lab で使う名前・アドレスが documentation 用であること |

## 実験の全体像

Lab 07/08 と同じ2ノード。server は TLS リスナー、client は TLS で繋ぐ。

```text
client (10.0.0.1) ------ eth1/eth1 ------ server (10.0.0.2:4433)
                                          openssl s_server
                                          cert CN=www.example.lab
                                          ALPN: h2, http/1.1
```

client は SNI=`www.example.lab`、ALPN offer=`h2,http/1.1` で接続する。その handshake を client 側で capture する。

```mermaid
sequenceDiagram
  participant C as client
  participant S as server

  Note over C,S: TCP already established (Lab 07)
  C->>S: ClientHello (SNI=www.example.lab, ALPN=[h2,http/1.1], ciphers, key share)
  Note right of C: cleartext — visible on the wire
  S->>C: ServerHello (chosen cipher, key share)
  Note left of S: cleartext — visible on the wire
  Note over C,S: keys derived; rest is encrypted
  S-->>C: {EncryptedExtensions (ALPN=h2)}
  S-->>C: {Certificate CN=www.example.lab}  (encrypted in TLS 1.3)
  S-->>C: {CertificateVerify, Finished}
  C-->>S: {Finished}
  Note over C,S: application data (HTTP) flows encrypted
```

両ノードとも `nicolaka/netshoot`(`openssl`、`tcpdump`、`tshark` 同梱)。追加イメージは不要。

## 必要なもの

推奨環境:

- Linux / WSL2 / Linux VM
- Docker
- containerlab
- tcpdump / tshark

使用イメージ:

- `nicolaka/netshoot:latest`

## 実行手順

```bash
./scripts/labctl.sh run tls-09
```

`labctl.sh run tls-09` は、deploy、証明書生成、s_server 起動、handshake の capture、s_client 実行、SNI/ALPN/証明書の確認、後片付けまで行う。

### 1. 作業ディレクトリへ移動する

```bash
cd protocol-lab/examples/tls-09
```

### 2. 起動して証明書を作る

```bash
sudo containerlab deploy -t tls-09.clab.yml
docker exec clab-tls-09-server sh -c \
  "openssl req -x509 -newkey rsa:2048 -nodes \
     -keyout /tmp/server.key -out /tmp/server.crt \
     -subj '/CN=www.example.lab' -days 30 -addext 'subjectAltName=DNS:www.example.lab'"
```

自己署名の証明書。閉じた Lab 用で、公開 CA は使わない。

### 3. server で TLS リスナーを起動する

```bash
docker exec -d clab-tls-09-server sh -c \
  "openssl s_server -accept 4433 -cert /tmp/server.crt -key /tmp/server.key -alpn h2,http/1.1 -www -quiet"
```

`-alpn h2,http/1.1` で、server が話せる application protocol を宣言する。

### 4. client で capture を仕込む

別シェルで capture(handshake を全部取りたいので `-s0`)。

```bash
docker exec -it clab-tls-09-client tcpdump -i eth1 -s0 -n "tcp port 4433"
```

### 5. TLS で接続する

```bash
docker exec -it clab-tls-09-client sh -c \
  "echo Q | openssl s_client -connect 10.0.0.2:4433 -servername www.example.lab -alpn h2,http/1.1 -tls1_3"
```

見るポイント(`s_client` の出力):

```text
subject=CN = www.example.lab
issuer=CN = www.example.lab
...
ALPN protocol: h2
...
Protocol  : TLSv1.3
Cipher    : TLS_AES_256_GCM_SHA384
Verify return code: 18 (self signed certificate)
```

- `subject=CN = www.example.lab`: server が提示した証明書。
- `ALPN protocol: h2`: client と server が `h2`(HTTP/2)で合意した。
- `Protocol : TLSv1.3`。
- `Verify return code: 18`: 自己署名なので検証は失敗扱い(公開 CA でない)。Lab では想定内。

### 6. capture から「平文で見える部分」を読む

`tshark` があれば、ClientHello の中の SNI と ALPN offer を抜き出せる。

```bash
docker exec clab-tls-09-client sh -c \
  "tshark -r /tmp/tls-09.pcap -Y 'tls.handshake.type==1' \
     -T fields -e tls.handshake.extensions_server_name -e tls.handshake.extensions_alpn_str"
```

期待:

```text
www.example.lab   h2,http/1.1
```

つまり **SNI と ALPN offer は ClientHello に平文で入っている**。一方、証明書は TLS 1.3 では暗号化された後に送られるので、capture から中身は読めない(`s_client` は接続の端点なので復号して表示できる)。

## 期待出力

- `s_client`: `CN = www.example.lab`、`ALPN protocol: h2`、`TLSv1.3`。
- `tshark`(あれば): ClientHello の `server_name` = `www.example.lab`、`alpn` = `h2,http/1.1`。
- capture: ClientHello / ServerHello は読めるが、Certificate は暗号化されて読めない。

## なぜそう動くのか

TLS は「暗号化」と「相手が本物かの確認」を、TCP の上に足す層。1本の TLS 接続はまず handshake で、使う暗号方式と鍵、そして application protocol を決める。

- **SNI が平文なのはなぜか**: server は1つの IP で複数のサイトを提供しうる。どの証明書を出すかを選ぶには、暗号鍵が決まる前に「どのサイト宛てか」を知る必要がある。だから ClientHello に平文で入る。(これを隠すのが ECH。このLabの範囲外。)
- **ALPN は何を決めるか**: HTTP/2(`h2`)か HTTP/1.1 か、といった上位プロトコルを、handshake の中で1往復で合意する。別途ネゴシエーションの往復を足さずに済む。
- **TLS 1.3 で証明書が暗号化されるのはなぜか**: ClientHello / ServerHello で鍵材料(key share)を交換した直後に鍵が導出され、以降(EncryptedExtensions、Certificate、Finished)は暗号化される。TLS 1.2 では証明書は平文だったが、1.3 では隠れる。だから on-path の観測者には、どの証明書かは見えない(SNI からサイトは推測できるが)。

要点:**暗号化が始まる境界を、capture の上で指させる**こと。ClientHello/ServerHello までは平文、その先は暗号化。

## 詰まりやすい点

- **SNI と証明書の CN を混同する**。SNI は client が「このサイト宛て」と平文で伝える希望。CN/SAN は server が返す証明書の名前。
- **`Verify return code: 18` をバグと思う**。自己署名だから検証は失敗扱い。公開 CA なら 0。
- **TLS 1.2 と 1.3 の違い**。1.2 では証明書が平文で見える。このLabは 1.3 を強制しているので暗号化される。`-tls1_2` にすると capture で証明書が読めることも確認できる。
- **ALPN が空**。server 側に `-alpn` を付け忘れると negotiation されない。
- **capture のサイズ**。`-s0` を付けないと truncate されて handshake を取りこぼすことがある。
- **ECH**。SNI を隠す仕組みはあるが、既定では有効でない。このLabでは SNI は見える。

## 後片付け

```bash
sudo containerlab destroy -t tls-09.clab.yml --cleanup
```

`labctl.sh run tls-09` を使った場合は、スクリプトが最後に destroy する。

## 確認問題

1. TLS はどの層の上に乗り、どの層の下にあるか。
2. SNI は誰が何のために送るか。なぜ平文なのか。
3. ALPN は何を決めるか。このLabでは何が選ばれたか。
4. TLS 1.3 で、capture から読めるのはどのメッセージまでか。証明書は読めるか。理由は。
5. `Verify return code: 18` は何を意味するか。公開 CA だとどうなるか。
6. TLS 1.2 と 1.3 で、証明書の見え方はどう違うか。

## References

- [RFC 8446: The Transport Layer Security (TLS) Protocol Version 1.3](https://www.rfc-editor.org/rfc/rfc8446)
- [RFC 6066: TLS Extensions (Server Name Indication)](https://www.rfc-editor.org/rfc/rfc6066)
- [RFC 7301: TLS Application-Layer Protocol Negotiation (ALPN)](https://www.rfc-editor.org/rfc/rfc7301)
- [RFC 5737: IPv4 Address Blocks Reserved for Documentation](https://www.rfc-editor.org/rfc/rfc5737)
- [openssl s_client manual page](https://docs.openssl.org/master/man1/openssl-s_client/)
