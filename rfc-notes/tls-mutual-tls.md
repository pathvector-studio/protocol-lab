# Mutual TLS (mTLS) Reading Guide for Lab 15

This guide helps you read the RFC sections that matter for TLS Lab 15. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、TLS Lab 15 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 8446: TLS 1.3](https://www.rfc-editor.org/rfc/rfc8446)
- [RFC 5280: X.509 Certificates and CRLs](https://www.rfc-editor.org/rfc/rfc5280)

## Reading Goal

For this lab, read mTLS as *server authentication (Lab 09) made symmetric*: the same certificate machinery, applied to the client as well. The new pieces are the CertificateRequest and the client's Certificate + CertificateVerify.

日本語: このLabでは、mTLS を「server 認証(Lab 09)を対称にしたもの」として読みます。同じ証明書の仕組みを client にも適用するだけ。増えるのは CertificateRequest と、client 側の Certificate + CertificateVerify です。

Start with these ideas:

- In server-only TLS the client checks the server; in mTLS the server also checks the client.
- The server asks with a CertificateRequest and states which CAs it will accept.
- The client proves possession of its private key with CertificateVerify — a cert alone is not enough.

## Lab #15 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 8446 | 4.3.2 | CertificateRequest(server が client 証明書を要求、受理する CA を示す) |
| 2 | RFC 8446 | 4.4.2 | Certificate(client も証明書を送る。1.3 では暗号化) |
| 3 | RFC 8446 | 4.4.3 | CertificateVerify(秘密鍵の所持を署名で証明) |
| 4 | RFC 5280 | 4.1, 6 | X.509 の構造と chain 検証(CA 署名をたどる) |
| 5 | RFC 8446 | 2 | 1-RTT handshake 全体のどこに上記が入るか |

## server 認証と mTLS

Lab 09 と Lab 15 の差分。

| | server-only TLS (Lab 09) | mutual TLS (Lab 15) |
|---|---|---|
| 誰が誰を検証 | client → server | client ⇄ server(相互) |
| 追加メッセージ | — | CertificateRequest / client Certificate / CertificateVerify |
| 弾かれる相手 | 偽 server | 証明書を出せない/信頼外の CA の client |

- server-only は「正しい相手につないでいるか」を client が確認するだけ。
- mTLS は「つないできた相手を server も確認する」。両者が同じ(あるいは互いに信頼する)CA を基点にする。

## CertificateRequest — 「あなたも証明して」

RFC 8446 4.3.2。

- server が handshake 中に送る。「client 証明書をよこせ」という要求。
- 受理する CA の名前(distinguished names)を載せられる。client はこれを見て、どの証明書を出せばよいか選ぶ。
- Lab の `openssl s_client` 出力の `Acceptable client certificate CA names` が、まさにこの CertificateRequest の中身。
- `openssl s_server -Verify`(大文字)は client 証明書を**必須**にし、`-verify`(小文字)は**任意**(要求はするが無くても通す)。

## 証明書 + 秘密鍵の証明

RFC 8446 4.4.2 / 4.4.3。

- **Certificate**: client が自分の証明書(chain)を送る。
- **CertificateVerify**: それまでの handshake 内容に、証明書の**秘密鍵で署名**する。これで「証明書を持っているだけ」でなく「対応する秘密鍵を持つ本人」だと示す。
- 証明書は公開情報なので、CertificateVerify が無ければ他人の証明書を貼るだけでなりすませてしまう。ここが要。

## chain 検証(RFC 5280)

- 受け取った証明書が、検証側の信頼する CA まで署名でつながるかを確認する。
- Lab では1つの `Protocol Lab CA` が server/client 両方に署名。両端がこの CA を `-CAfile` で信頼しているので成立する。
- client 証明書を別の CA で署名すると、server は chain をたどれず拒否する。

## TLS 1.3 では見えない

RFC 8446 2。

- ServerHello の後に鍵が導出され、以降(CertificateRequest、双方の Certificate、CertificateVerify、Finished)は**暗号化**される。
- したがって passive capture からは client 証明書も CertificateRequest も読めない。読めるのは接続の**端点**(openssl s_client / s_server)だけ。
- Lab 09 で「1.3 では server 証明書が暗号化される」ことを見たのと同じ理由。

## Message から読む

Lab の openssl 出力を RFC の用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `Acceptable client certificate CA names` | server が CertificateRequest を送った(受理 CA の一覧) |
| `Verify return code: 0 (ok)` | 証明書 chain の検証成功 |
| `tlsv13 alert certificate required` | client が証明書を出さず、server が拒否 |
| `-Verify 1` / `-verify 1` | 必須 / 任意 の client 認証 |

## よくある誤解

- mTLS は server 認証の置き換えではなく**追加**(両方向)。
- `-Verify`(必須)と `-verify`(任意)は挙動が違う。
- 証明書を出すだけでは足りない。CertificateVerify(秘密鍵の証明)が要る。
- 別の CA で署名した client 証明書は、server が信頼していなければ通らない。
- TLS 1.3 では client 証明書は capture に出てこない(暗号化)。

## 前後の Lab とのつながり

- Lab 09(server 認証)の証明書・chain の理解がそのまま土台。
- mTLS は service mesh、VPN、ゼロトラスト、API gateway で広く使われる。
- 証明書を「DNS に載せて」検証する DANE や、機械 ID を配る SPIFFE などへ発展する。
