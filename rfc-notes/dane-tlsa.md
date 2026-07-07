# DANE / TLSA Reading Guide for Lab 17

This guide helps you read the RFC sections that matter for Lab 17. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、Lab 17 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 6698: DANE / TLSA](https://www.rfc-editor.org/rfc/rfc6698)
- [RFC 7671: DANE Updates and Operational Guidance](https://www.rfc-editor.org/rfc/rfc7671)
- [RFC 4034: DNSSEC Resource Records](https://www.rfc-editor.org/rfc/rfc4034)

## Reading Goal

For this lab, read DANE as *moving the anchor of trust from a CA to the domain owner, secured by DNSSEC*. A TLSA record in DNS says "this is my certificate"; DNSSEC (Lab 13) makes that statement trustworthy.

日本語: このLabでは、DANE を「信頼の起点を CA からドメイン所有者へ移し、DNSSEC で守る」ものとして読みます。DNS の TLSA レコードが「これが私の証明書だ」と宣言し、DNSSEC(Lab 13)がその宣言を信頼できるものにする。

Start with these ideas:

- A TLSA record pins a certificate (or its public key) for a specific service.
- DANE only works if the TLSA is DNSSEC-signed — otherwise it can be forged.
- With DANE, a self-signed certificate can be trustworthy; a mismatching cert is rejected.

## Lab #17 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 6698 | 2.1 | TLSA の3フィールド: usage / selector / matching type |
| 2 | RFC 6698 | 3 | `_port._proto.name` の命名と、TLS での使い方 |
| 3 | RFC 7671 | 4-5 | DANE-EE(`3`)推奨、運用上の注意 |
| 4 | RFC 4034 | 3 | RRSIG(TLSA も署名される。Lab 13 の復習) |

## TLSA の3フィールド

RFC 6698 2.1。TLSA レコードは `usage selector matching-type <data>`。

| フィールド | 値 | 意味(このLab) |
|---|---|---|
| usage | `3` | DANE-EE: end-entity 証明書そのものを pin(PKIX/CA を通さない) |
| selector | `1` | SubjectPublicKeyInfo: 公開鍵情報を対象にする(証明書全体でなく) |
| matching type | `1` | SHA-256: 対象の SHA-256 ハッシュを比較 |

- `3 1 1` = 「この公開鍵の SHA-256 と一致する end-entity 証明書だけを信じよ」。
- 他に usage `2`(DANE-TA、独自 CA を pin)などもあるが、`3`(DANE-EE)が運用上シンプルで推奨(RFC 7671)。

## 名前の付け方

RFC 6698 3。

- `_<port>._<proto>.<hostname>` の形。例: `_443._tcp.www.example.lab`。
- ポートとプロトコルが頭に付くので、「www.example.lab の 443/tcp が使う証明書」を指す。
- サービスごとに TLSA を分けられる(443 と 8443 は別)。

## なぜ DNSSEC が必須か

RFC 6698 前提、RFC 4034。

- TLSA は「どの証明書を信じるか」を宣言する。もしこの宣言が改ざんできれば、攻撃者は自分の証明書を pin して成りすませる。
- だから TLSA は **DNSSEC で署名**されていなければならない。RRSIG(Lab 13)が付いて初めて、client は TLSA を信頼できる。
- 「DANE = TLSA + DNSSEC」。片方だけでは意味をなさない。

## CA との関係

- 通常の PKIX: client が信頼する CA が証明書に署名 → client は CA 経由で信じる。
- DANE: ドメイン所有者が DNS に証明書を pin → DNSSEC が保証 → client は DNS 経由で信じる。
- DANE-EE(`3`)では **CA は不要**。自己署名でも、TLSA と一致すれば valid。
- DANE を PKIX に「追加」する使い方もある(CA も通り、かつ TLSA でも pin)。このLabは CA なしの DANE-EE。

## Message から読む

Lab の出力を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `TLSA 3 1 1 <hash>` | DANE-EE / SPKI / SHA-256 の pin |
| その隣の `RRSIG TLSA` | TLSA が DNSSEC 署名されている(信頼できる) |
| `matched the EE certificate` | 提示された証明書が TLSA と一致 |
| `Verify return code: 0 (ok)` | DANE 検証成功(CA なしでも) |
| `no matching DANE TLSA records` (65) | 証明書が TLSA と不一致 → 拒否 |

## よくある誤解

- DANE を DNSSEC 抜きで使えると思う。署名なし TLSA は偽装可能。
- TLSA の名前を `www.example.lab` だけにする。正しくは `_443._tcp.www.example.lab`。
- 自己署名 = 危険と決めつける。DANE で pin されていれば正当。
- impostor が別 CA で署名されていれば通ると思う。DANE は指紋の一致だけを見る。
- `3 1 1` を覚えていない。usage/selector/matching の3つ。

## 前後の Lab とのつながり

- Lab 13(DNSSEC)が土台。TLSA を守るのはその RRSIG。
- Lab 09(TLS 証明書)の「証明書をどう信じるか」に、CA 以外の答えを与える。
- DANE は SMTP のopportunistic TLS 強化(RFC 7672)など、実運用でも使われる。証明書の信頼を DNS に置くという発想は、今後の web PKI 議論にもつながる。
