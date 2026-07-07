# Split-Horizon DNS Reading Guide for Lab 42

This guide points at the material that matters for Lab 42. Split-horizon (split-brain) DNS is an operational technique built on ordinary authoritative DNS: serve different answers for the same name depending on who is asking. The references are the DNS model plus the terminology for views/scoped answers.

日本語: この guide は Lab 42 の読みどころを整理したものです。split-horizon(split-brain)DNS は通常の authoritative DNS の上に立つ運用技法で、同じ名前に、聞く相手によって異なる答えを返す。参照は DNS のモデルと、view/スコープ付き応答の用語です。

Target material:

- [RFC 1034: Domain Names — Concepts and Facilities](https://www.rfc-editor.org/rfc/rfc1034) — authoritative servers and zones
- [RFC 8499: DNS Terminology](https://www.rfc-editor.org/rfc/rfc8499) — "view" / split DNS terminology
- [RFC 6950: Architectural Considerations on Application Features in the DNS](https://www.rfc-editor.org/rfc/rfc6950) — scoped/conditional answers and their caveats

## Reading Goal

Read split-horizon DNS as *"one authoritative name, several answer sets, chosen by the querier."* A normal authoritative server gives everyone the same answer for a name. A split-horizon server keeps multiple **views**, each with its own copy of the zone, and picks a view based on the **client's source address** (or key, interface). Inside users can be handed a private path; outside users a public one — same name, different address.

日本語: split-horizon DNS は「1つの authoritative な名前、複数の答えの組、問い合わせ元で選ぶ」と読みます。通常の authoritative サーバは名前に対し全員へ同じ答えを返す。split-horizon サーバは複数の **view**(各自がゾーンのコピーを持つ)を保ち、**クライアントの送信元アドレス**(や鍵、インターフェース)で view を選ぶ。内部ユーザには private な経路、外部には public を——同じ名前、違うアドレス。

Start with these ideas:

- A **view** is a named container holding its own version of one or more zones.
- Views are matched **top-down** by `match-clients` (source address / ACL); first match wins.
- The same **name** can therefore resolve to different records per view.
- Common use: internal address inside, public address outside (hide internal topology).

## Lab #42 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | RFC 8499 | "view" / split DNS の用語 |
| 2 | RFC 1034 | authoritative / zone の基本 |
| 3 | RFC 6950 | スコープ付き応答の注意点(一貫性・キャッシュ) |

## view と match-clients

BIND views / RFC 8499。

- **view** は、独自のゾーン定義(ファイル)を持つ名前付きコンテナ。
- サーバは受け取ったクエリの **送信元** を、view の `match-clients` に **上から順** に照合し、最初に一致した view を使う。
- Lab の設定:
  - `view "internal" { match-clients { 10.0.1.0/24; }; zone app.lab. → db.internal }`
  - `view "external" { match-clients { any; }; zone app.lab. → db.external }`
- 内部クライアント(10.0.1.10)は internal に一致 → `app.lab. A 10.0.0.5`。外部(203.0.113.10)は internal に一致せず external(any)→ `app.lab. A 203.0.113.5`。
- **順序が重要**: 具体的な view を先に、`any` を最後に置く。逆だと全員が最初の view に落ちる。

## なぜ使うか

- **内外で違う経路**: 内部ユーザにはサーバの private IP(社内 LAN 直結)、外部には public IP(ファイアウォール/公開 LB 経由)を返す。
- **内部トポロジの隠蔽**: 外部に private アドレスや内部専用ホストを見せない(情報漏れ防止)。
- **同一名の一貫運用**: `app.lab` という1つの名前を、場所に応じて正しい面に解決させる(ユーザは URL を変えない)。
- 企業ネットや DMZ で定番。

## 注意点(RFC 6950 の含意)

- **キャッシュとの相性**: 応答は resolver にキャッシュされる。ある view の答えが別の場所で使い回されると誤誘導しうる。境界(内/外の resolver 分離)を明確にする。
- **一貫性の負担**: view ごとにゾーンのコピーを保つため、更新漏れで内外がずれる。自動化/共通データからの生成が要る。
- **判定は送信元頼み**: NAT や VPN で送信元が変わると、意図と違う view に落ちうる。ACL 設計に注意。

## Message から読む(Lab の出力)

| 見えるもの | 意味 |
|---|---|
| internal: `app.lab -> 10.0.0.5` | 内部 view(private 面) |
| external: `app.lab -> 203.0.113.5` | 外部 view(public 面) |
| 2つが異なる | 同一名が送信元で別答え(split-horizon 成立) |

## よくある誤解

- **round-robin と混同する**。RR(Lab 41)は同じ答えの順序を回す。split-horizon は **答えそのもの** を相手で変える。目的が別。
- **view の順序を無視する**。上から照合し最初の一致が勝つ。`any` を先に置くと全員そこへ。
- **1ゾーンで済むと思う**。各 view は自分のゾーンコピーを持つ。データ同期の運用が要る。
- **キャッシュを忘れる**。内外の resolver を分けないと、view の答えが混ざりうる。
- **送信元が信頼できると思う**。NAT/VPN/spoof で送信元は変わりうる。ACL は慎重に。

## 前後の Lab とのつながり

- DNS の基礎(Lab 05/06)と round-robin(Lab 41)の延長。RR は「順序」、views は「内容」を変える。
- 内部=private / 外部=public の二面は、NAT(Lab 20)や DNAT(Lab 40)で作る二面と対応する(名前解決側の面)。
- rp_filter(Lab 39)や policy routing(Lab 38)と同じく、**送信元** を判断材料にする一連の技法。
