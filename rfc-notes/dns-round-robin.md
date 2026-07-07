# DNS Round-Robin Reading Guide for Lab 41

This guide points at the material that matters for Lab 41. DNS round-robin is a load-spreading technique built on ordinary DNS: give one name several address records and let the server rotate their order. The references are the DNS message model and the load-balancing considerations.

日本語: この guide は Lab 41 の読みどころを整理したものです。DNS round-robin は通常の DNS の上に立つ負荷分散の技法で、1つの名前に複数のアドレスレコードを持たせ、サーバがその順序を回す。参照は DNS メッセージのモデルと負荷分散の考え方です。

Target material:

- [RFC 1035: Domain Names — Implementation and Specification](https://www.rfc-editor.org/rfc/rfc1035) — the A record and RRsets
- [RFC 1794: DNS Support for Load Balancing](https://www.rfc-editor.org/rfc/rfc1794) — the round-robin technique itself
- [RFC 8499: DNS Terminology](https://www.rfc-editor.org/rfc/rfc8499) — RRset, authoritative, resolver terms

## Reading Goal

Read DNS round-robin as *"one name, several addresses, order rotated per answer."* A name can hold multiple **A records** (an RRset). Clients typically try the **first** address returned. If the server rotates the order on each response, different clients get a different first address — spreading load across the set, entirely at the naming layer, before any packet reaches the servers.

日本語: DNS round-robin は「1つの名前、複数のアドレス、応答ごとに順序を回す」と読みます。名前は複数の **A レコード**(RRset)を持てる。クライアントはふつう返ってきた **先頭** のアドレスを使う。サーバが応答ごとに順序を回せば、クライアントごとに先頭が変わり、集合全体へ負荷が散る——パケットがサーバに届く前、名前解決の層で。

Start with these ideas:

- A name's **A records** form an **RRset**; a response can carry all of them.
- Clients tend to use the **first** record, so the order matters.
- **Round-robin** rotates the RRset order per response (BIND: `rrset-order cyclic`).
- It is **coarse and stateless** — no health checks, no true balancing, and caching blunts it.

## Lab #41 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | RFC 1035 §3.4.1 | A レコード、RRset(複数レコード) |
| 2 | RFC 1794 | round-robin による負荷分散 |
| 3 | RFC 8499 | RRset / authoritative / resolver の用語 |

## RRset と「先頭を使う」慣習

RFC 1035 / RFC 8499。

- 同じ名前・型の複数レコードは **RRset** を成す。`web.lab. A 203.0.113.11/.12/.13` は3レコードの RRset。
- 応答はふつう **RRset 全体** を返す(3つとも)。
- クライアント(や stub resolver)は多くの場合 **先頭** のアドレスに接続する。だから **順序** が誰に当たるかを決める。

## round-robin(順序を回す)

RFC 1794 / BIND。

- サーバが応答のたびに RRset の順序を **回転** させる。BIND では `rrset-order { order cyclic; }`(既定でも cyclic 寄り)。
- Lab の観察: 連続クエリで先頭が `.11 → .12 → .13 → .11 …` と巡回する。
- 結果、次々に問い合わせるクライアント群が異なる先頭を受け取り、3つの backend に **おおまかに** 分散する。
- ネットワーク/転送層(anycast/ECMP/IPVS)ではなく **名前解決層** で分散する点が特徴。

## 負荷分散ファミリでの位置づけ

| 手法 | どこで分散 | 単位 | 状態/健全性 |
|---|---|---|---|
| anycast (31) | routing の best-path | クライアント→1インスタンス | routing 依存 |
| ECMP (32) | routing の multipath hash | flow→1リンク | ステートレス |
| IPVS LB (33) | director(NAT) | 接続→1 backend | ステートフル + 健全性可 |
| **DNS RR (41)** | **名前解決** | **解決→1先頭アドレス** | **なし(粗い)** |

- DNS RR は最も **手軽** だが最も **粗い**。健全性チェックが無く、死んだ backend の A も返し続ける(別途 監視/低 TTL/撤去が要る)。

## caching が効きを鈍らせる

RFC 1035 の TTL。

- 応答は **TTL** の間、resolver/クライアントにキャッシュされる。キャッシュ中は同じ順序が使い回され、回転が効かない。
- だから RR 用の A は **短い TTL**(Lab は 30 秒)にすることが多い。ただし短すぎるとクエリ増。
- また、resolver 自身が並べ替える/固定する実装もあり、分散はベストエフォート。

## Message から読む(Lab の出力)

| 見えるもの | 意味 |
|---|---|
| `web.lab. A .11 / .12 / .13`(3行) | 1名前・3アドレスの RRset |
| 連続クエリの先頭が `.11→.12→.13→…` | サーバが順序を回している(cyclic) |
| distinct first-records = 3 | 3つすべてが先頭になった(巡回) |
| TTL 30 | キャッシュを短くして再解決・再分散を促す |

## よくある誤解

- **真のロードバランスと思う**。DNS RR は粗い分散。実負荷やコネクション数は見ない。
- **健全性を見ると思う**。素の DNS RR は死んだ backend も返す。監視+低 TTL+撤去 or 実 LB が要る。
- **必ず均等と思う**。caching・resolver の挙動・クライアントの選択でばらつく。ベストエフォート。
- **先頭以外も使われると思う**。多くのクライアントは先頭だけ使う(だから順序が効く)。
- **TTL を無視する**。長い TTL はキャッシュで回転を殺す。RR には短い TTL。

## 前後の Lab とのつながり

- 負荷分散ファミリの締め: anycast(31, routing)、ECMP(32, links)、IPVS(33, director)、DNS RR(41, 名前解決)。層が違う。
- DNS の基礎(Lab 05/06)の応用。RRset・TTL・authoritative の理解が土台。
- 実運用では DNS RR + 実 LB(Lab 33)や anycast(Lab 31)を **組み合わせる**(GeoDNS→anycast→LB など)。
