# HTTP Redirects and Cookies Reading Guide for Lab 27

This guide helps you read the RFC sections that matter for Lab 27. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、Lab 27 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 9110: HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110)
- [RFC 6265: HTTP Cookies](https://www.rfc-editor.org/rfc/rfc6265)

## Reading Goal

For this lab, read redirects and cookies as the two mechanisms that make a stateless protocol feel stateful: one steers the client, the other gives it a token to carry.

日本語: このLabでは、redirect と cookie を「stateless なプロトコルに状態があるように見せる2つの仕組み」として読みます。片方は client を誘導し、もう片方はトークンを持たせる。

Start with these ideas:

- A 3xx response tells the client to go elsewhere, via the Location header.
- The client — not the server — decides to follow the redirect.
- Set-Cookie hands the client a token; the client returns it as Cookie on later requests.

## Lab #27 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 9110 | 15.4 | 3xx redirect の意味(301/302/303/307/308) |
| 2 | RFC 9110 | 10.2.2 | `Location` ヘッダ |
| 3 | RFC 6265 | 3 | `Set-Cookie` / `Cookie` の構文 |
| 4 | RFC 6265 | 4.1, 5.2 | cookie 属性(Path/Domain/Secure/HttpOnly/SameSite) |

## redirect(3xx + Location)

RFC 9110 15.4。

- サーバは「このリソースは別の場所にある/こっちを見よ」を、**3xx ステータス**と **`Location` ヘッダ**で伝える。
- 主な種類:
  - **301 Moved Permanently**: 恒久移設。
  - **302 Found**: 一時的(このLab)。
  - **303 See Other**: POST 後に GET で別ページへ、など。
  - **307/308**: メソッドを保持したまま redirect(307=一時、308=恒久)。
- 行き先は **本文ではなく `Location` ヘッダ**。

## 追従は client の仕事

- サーバは行き先を示すだけ。実際にそこへリクエストし直すかは **client** が決める。
- ブラウザは自動で追従する。`curl` は既定で追従せず、`-L` で追従する。
- 追従回数には上限があり(ループ防止)、無限 redirect は打ち切られる。

## cookie(Set-Cookie / Cookie)

RFC 6265。

- **`Set-Cookie: name=value; attrs`**: サーバが応答で client にトークンを渡す。
- client はそれを保存し、**同じサーバへの以後のリクエストに `Cookie: name=value` を自動で付ける**。
- サーバはその value を見て client を識別する。これで stateless な HTTP の上に「セッション」ができる。
- `curl` では `-c <jar>`(保存)/ `-b <jar>`(送信)。ブラウザは両方自動。

## cookie の属性(セキュリティ)

RFC 6265 4.1、および後続の議論。

| 属性 | 意味 |
|---|---|
| Path / Domain | どの URL/ホストに送るか(スコープ) |
| Expires / Max-Age | いつまで保持するか(無ければセッション cookie) |
| Secure | HTTPS のときだけ送る |
| HttpOnly | JavaScript から読めない(XSS 対策) |
| SameSite | クロスサイト送信を制限(CSRF 対策) |

- このLabは最小限(Path のみ)。実運用ではこれらが重要。

## stateless という前提

- HTTP 自体は各リクエストが独立(stateless)。サーバは前のリクエストを覚えていない。
- 「覚えている」ように見えるのは、client が cookie を送り返すから。サーバ側の記憶ではなく、client が運ぶトークンが手がかり。
- だから cookie を消せばログアウト、cookie を盗まれればなりすまし。属性で守るのはこのため。

## Message から読む

Lab の出力を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `HTTP/1.1 302 Found` + `Location: /new` | redirect(行き先を提示) |
| `curl -L` の `[final] .../new` | client が追従した |
| `Set-Cookie: session=abc123` | サーバがトークンを渡す |
| `Cookie: session=abc123`(次の request) | client が送り返す |

## よくある誤解

- redirect にサーバが連れて行く、ではない。追従は client。
- 行き先を本文に探す、は誤り。`Location` ヘッダ。
- cookie をサーバが覚えている、は誤り。覚えるのは client。
- `-c`(保存)と `-b`(送信)は別。
- cookie の属性(Secure/HttpOnly/SameSite)はセキュリティ上必須。

## 前後の Lab とのつながり

- Lab 10(HTTP 基礎)の method/status/header の上に、redirect と cookie を足した。
- cookie の Secure は Lab 09(TLS)/ Lab 14(暗号化 DNS)と同じ「経路上で守る」思想。
- セッション/認証は、mTLS(Lab 15)や OAuth など、より強い認証へと発展する。
