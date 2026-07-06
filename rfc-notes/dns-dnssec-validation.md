# DNSSEC Validation Reading Guide for Lab 13

This guide helps you read the RFC sections that matter for DNS Lab 13. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、DNS Lab 13 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 4033: DNS Security Introduction and Requirements](https://www.rfc-editor.org/rfc/rfc4033)
- [RFC 4034: Resource Records for the DNS Security Extensions](https://www.rfc-editor.org/rfc/rfc4034)
- [RFC 4035: Protocol Modifications for the DNS Security Extensions](https://www.rfc-editor.org/rfc/rfc4035)
- [RFC 6605: ECDSA for DNSSEC](https://www.rfc-editor.org/rfc/rfc6605)

## Reading Goal

For this lab, read DNSSEC as *authentication for DNS answers*, not encryption. The data stays public; what DNSSEC adds is a way to prove an answer came from the zone and was not modified in transit.

日本語: このLabでは、DNSSEC を「DNS の答えの暗号化」ではなく「認証」として読みます。データは公開のまま。DNSSEC が足すのは「この答えはそのゾーンが出したもので、途中で改変されていない」ことを証明する仕組みです。

Start with these ideas:

- A signed zone adds `RRSIG` (signatures), `DNSKEY` (public keys), and `NSEC` (denial of existence) next to the normal records.
- A validating resolver holds a trust anchor and rejects answers it cannot verify (fail closed → SERVFAIL).
- The AD flag in a response means "I validated this"; the CD flag in a query means "do not validate for me".

## Lab #13 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 4033 | 2, 5 | DNSSEC の目的、trust anchor と authentication chain |
| 2 | RFC 4034 | 2 | `DNSKEY` の形式(KSK/ZSK、flag 257/256) |
| 3 | RFC 4034 | 3 | `RRSIG` の形式(何を、どの鍵で署名したか) |
| 4 | RFC 4034 | 4 | `NSEC`(存在しない名前の否定証明) |
| 5 | RFC 4034 | 5 | `DS`(親から子ゾーンの鍵をつなぐ) |
| 6 | RFC 4035 | 3.2.3, 4.3 | validating resolver、**AD** と **CD** フラグ |

## 認証であって暗号化ではない

よくある誤解は「DNSSEC で DNS が暗号化される」というもの。違う。

- DNSSEC が守るのは **真正性(発信元認証)** と **完全性(改ざん検出)**。
- 中身は平文のまま。誰が何を引いたかは経路上から見える(それを隠すのは DoT/DoH や QNAME minimization の話)。
- Lab 09 の TLS(通信の暗号化)とは目的が別。DNSSEC は「答えそのものが本物か」を鍵で保証する。

## 署名済みゾーンに増えるレコード

RFC 4034 が定める3つ(+親側の DS)。

| レコード | 役割 |
|---|---|
| `DNSKEY` | ゾーンの公開鍵。KSK(flag 257)と ZSK(flag 256) |
| `RRSIG` | ある RRset に対する署名。対象型・アルゴリズム・鍵タグ・有効期間を持つ |
| `NSEC` | 「この名前とこの名前の間に何も無い」ことの証明(否定応答用) |
| `DS` | 親ゾーンに置く、子ゾーンの KSK のハッシュ。信頼を親から子へつなぐ |

Lab 13 の署名済みゾーン(`auth/db.example.lab.signed`)を `cat` すると、これらが素のレコードの隣に並んでいるのが見える。

## KSK と ZSK

RFC 4034 2、実運用の慣習。

- **ZSK**(Zone Signing Key, flag 256): ゾーンの全 RRset を署名する。よく使うので短命・交換しやすく。
- **KSK**(Key Signing Key, flag 257): DNSKEY RRset だけを署名する。trust anchor / DS の対象になる。長寿命に。
- この分離のおかげで、ZSK を回しても親に登録した信頼(DS / trust anchor)を変えずに済む。

## 信頼の連鎖と trust anchor

RFC 4033 5、RFC 4035 5。

- resolver は「最初から信頼する鍵」= **trust anchor** を持つ。本番では root の KSK。
- root は TLD の DS を署名し、TLD は子の DS を署名し…と **DS → DNSKEY → RRSIG** の連鎖で下りていく。
- Lab 13 は連鎖を省略し、`example.lab` の KSK を **直接 trust anchor** に設定する(island of trust)。これは RFC 4033 が認める、局所的に DNSSEC を張る方法。

## AD フラグと CD フラグ

RFC 4035 3.2.3(AD)と 3.2.2 / 4.3(CD)。

| フラグ | 誰が付ける | 意味 |
|---|---|---|
| **AD**(Authenticated Data) | resolver が応答に | trust anchor まで署名を検証できた |
| **CD**(Checking Disabled) | client が query に | resolver は検証せず、生データをよこせ |

- `dig +dnssec` は DO ビット(DNSSEC OK)を立てて RRSIG を要求する。検証が通れば応答に AD が立つ。
- `dig +cd` は CD を立てる。resolver は検証をスキップするので、bogus なデータでも返る。原因調査に使うが、常用は DNSSEC の無効化。

## 壊れていたら拒否する(fail closed)

RFC 4035 5。

- resolver が署名を検証できない(改ざん・期限切れ・鍵不一致など)場合、古い/怪しいデータを返すのではなく **SERVFAIL** で拒否する。
- Lab 13 では A レコードを1バイト書き換えるだけで RRSIG が合わなくなり、SERVFAIL になる。ログに `no valid signature found` が出る。
- 「答えが返らない」ことより「嘘の答えを返さない」ことを優先する設計。

## Message から読む

Lab の `dig` 出力を RFC の用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `flags: ... ad` | resolver が検証に成功(Authenticated Data) |
| `RRSIG A 13 ...` | A RRset の署名、アルゴリズム 13(ECDSAP256SHA256) |
| `DNSKEY 257 / 256` | KSK / ZSK |
| `status: SERVFAIL`(+ ログの no valid signature) | 検証失敗、fail closed |
| `+cd` で答えが返る | 検証を外した(CD)。正しさは保証されない |

## よくある誤解

- DNSSEC は暗号化ではない。真正性と完全性を守る。
- RRSIG(サーバが付ける署名)と AD(resolver が付ける検証済みフラグ)は別物。
- SERVFAIL はサーバ障害とは限らない。DNSSEC 検証失敗でも起きる。
- `+cd` で「直る」のは検証を切っているから。正しさの保証は消える。
- 署名には有効期限がある。期限切れも SERVFAIL の原因。

## 前後の Lab とのつながり

- Lab 05/06 は「名前をどう解決し、どれだけ cache するか」。答えの真偽は問わなかった。
- Lab 13 は「その答えは本物か」を鍵で確かめる。DNS の信頼性の土台。
- この先、DNSSEC は DoT/DoH(経路の暗号化)や DANE/TLSA(証明書を DNS に載せる)といった仕組みの前提になる。
