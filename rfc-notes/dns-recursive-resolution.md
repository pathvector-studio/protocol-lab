# DNS Recursive Resolution Reading Guide for Lab 05

This guide helps you read the RFC sections that matter for DNS Lab 05. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、DNS Lab 05 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 1034: Domain Names - Concepts and Facilities](https://www.rfc-editor.org/rfc/rfc1034)
- [RFC 1035: Domain Names - Implementation and Specification](https://www.rfc-editor.org/rfc/rfc1035)
- [RFC 8499: DNS Terminology](https://www.rfc-editor.org/rfc/rfc8499)

## Reading Goal

For this lab, read DNS resolution as a walk down a delegated tree, driven by one component (the recursive resolver) on behalf of another (the stub).

日本語: このLabでは、DNS の名前解決を「委任された木を上から下へ歩く処理」として読みます。歩くのは recursive resolver で、それを stub resolver が代わりに頼んでいる、という役割分担を意識します。

Start with these ideas:

- The domain name space is a tree. Each node has a label; a full name is the labels from a node up to the root.
- A zone is a cut of that tree that one set of servers is authoritative for.
- A parent zone **delegates** a child zone with NS records, plus **glue** (address records for the NS names).
- A stub resolver asks one question and sets RD (recursion desired).
- A recursive resolver walks the tree iteratively, following referrals, and caches what it learns.

## Lab #5 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 8499 | 2, 6 | stub / recursive / authoritative、referral、glue の用語をそろえる |
| 2 | RFC 1034 | 4.3.1 | recursive mode と iterative mode の違いを読む |
| 3 | RFC 1034 | 4.3.2 | name server が query に答えるアルゴリズム(委任を返す条件) |
| 4 | RFC 1034 | 5.3.3 | resolver が referral をたどって解決する流れ |
| 5 | RFC 1035 | 4.1 | message の question / answer / authority / additional セクション |

## Stub と Recursive と Authoritative

3つの役割を分けて読むと、Lab の出力が読みやすくなる。

- **stub resolver**: アプリの中の最小のクライアント。1つの recursive resolver に丸投げする。Lab では client の `dig`。
- **recursive resolver**: 実際に木を歩く。root から始め、referral をたどり、答えを cache する。Lab では resolver ノード。
- **authoritative server**: あるゾーンの正解を持つ。root は `.`、tld は `lab.`、auth は `example.lab.`。

RFC 8499 の用語で、この3つを別物として押さえておく。

## Referral と Glue

referral は「答え」ではなく「次に聞く相手」。

root に `www.example.lab A?` と聞くと、root は答えを持たないので、`lab.` の委任を返す。

```text
;; AUTHORITY SECTION:
lab.            IN  NS  ns.lab.
;; ADDITIONAL SECTION:
ns.lab.         IN  A   10.0.2.2      <- これが glue
```

glue がないと、resolver は `ns.lab.` の住所を知るためにまた別の解決を始めることになる。委任先の NS 名が委任元ゾーンの内側にある場合、glue は必須になる。

Lab 05 の3つのゾーンは、すべて NS + glue の組で委任を書いている。

## Recursive と Iterative

RFC 1034 4.3.1 の区別が、この Lab の中心。

- **recursive**: client → resolver の関係。client は「最後まで解決して」と頼む(RD=1)。
- **iterative**: resolver → 各 authoritative server の関係。resolver は1段ずつ referral をもらいながら自分で歩く。

同じ「解決」でも、client から見た1回のやり取りと、resolver が裏で行う複数のやり取りは別物。`dig +trace` は後者を client 側で再現して見せる。

## Message のセクション

RFC 1035 4.1 の4セクションを、Lab の出力に対応づける。

| セクション | 中身 | Lab での例 |
|---|---|---|
| Question | 聞いた名前・型 | `www.example.lab. IN A` |
| Answer | 答え | `www.example.lab. A 203.0.113.10`(auth の応答) |
| Authority | 権限を持つ NS | `lab. NS ns.lab.`(root の referral) |
| Additional | 補足(glue など) | `ns.lab. A 10.0.2.2` |

referral では Answer が空で、Authority と Additional に NS と glue が入る。この形を見分けられると、`dig +trace` の各段が読める。

## Root Hints の役割

resolver は「最初にどこへ聞くか」を知る必要がある。それが root hints。

本番の resolver は IANA が配る `named.root` を使い、13の root server を知っている。Lab 05 では、それを差し替えて、ローカルの `a.root.` (10.0.1.2) だけを教える。

```text
.           NS  a.root.
a.root.     A   10.0.1.2
```

root hints は「木の入口」を教えるだけ。そこから先は referral を追って歩く。

## BGP/RPKI との違い

前の4回(BGP/RPKI)とは、観察する対象が変わる。

- BGP は経路(reachability)を配る control plane。
- DNS は名前 → データ(A レコードなど)を引く仕組み。
- どちらも「委任」の考え方は共通(BGP は AS への委任、DNS はゾーンへの委任)。
- Lab 05 では、パケットよりも「誰が誰に何を聞き、何が返るか」の連鎖に集中する。

## よくある誤解

- stub resolver が木を歩くわけではない。歩くのは recursive resolver。
- root は `www.example.lab` の答えを持っていない。referral を返すだけ。
- referral は Answer セクションではなく Authority / Additional に入る。
- root hints は答えのキャッシュではなく、入口の一覧。
- この階層は DNSSEC 署名していない。だから resolver は検証をオフにしている。

## 次の Lab につながる問い

- 同じ名前を2回聞いたとき、2回目が速いのはなぜか(cache)。
- TTL が切れると何が起きるか。
- 存在しない名前を聞くと何が返るか(NXDOMAIN、negative caching)。

これらは Lab 06(cache、TTL、negative answer)で扱う。
