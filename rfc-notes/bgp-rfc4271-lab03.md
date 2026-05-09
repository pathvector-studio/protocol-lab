# RFC 4271 Reading Guide for BGP Lab 03

This guide helps you read the parts of RFC 4271 that matter for BGP Lab 03. It is meant to be used alongside the RFC, not instead of it.

日本語: この guide は、BGP Lab 03 に必要な RFC 4271 の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFC: [RFC 4271: A Border Gateway Protocol 4 (BGP-4)](https://www.rfc-editor.org/rfc/rfc4271)

## Reading Goal

For this lab, read BGP as a protocol that can carry multiple claims about reachability to the same prefix.

日本語: このLabでは、BGPを「同じprefixへの到達性について、複数の主張を運びうるプロトコル」として読みます。

Start with these ideas:

- A BGP route is a prefix plus path attributes.
- AS_PATH describes the AS sequence associated with a route.
- The origin AS is derived from the AS_PATH.
- The BGP table may contain more than one path for the same prefix.
- BGP alone does not prove that an origin AS is authorized to originate a prefix.

## Lab #3 で読む場所

| 優先 | RFC 4271 の章 | 読む目的 |
|---|---|---|
| 1 | 1.1 Definition of Commonly Used Terms | AS、BGP speaker、route、RIB の用語をそろえる |
| 2 | 3.1 Routes: Advertisement and Storage | route が prefix と path attributes の組であることを読む |
| 3 | 4.3 UPDATE Message Format | UPDATE が path attributes と NLRI を運ぶことを見る |
| 4 | 5.1.2 AS_PATH | AS_PATH と AS_SEQUENCE を読む |
| 5 | 9 UPDATE Message Handling | BGP speaker が受け取った route を処理する流れを読む |

## Origin AS の読み方

Lab 03 では、`r2` が同じ prefix に対して2つの path を見る。

```text
203.0.113.0/24
  AS_PATH: 65001

203.0.113.0/24
  AS_PATH: 65003
```

このとき、AS_PATH の右端を origin AS として読む。

```text
AS_PATH 65001 -> origin AS65001
AS_PATH 65003 -> origin AS65003
```

Lab 03 の構成では AS_PATH が1つのASだけなので見やすい。実際のインターネットでは AS_PATH がもっと長くなる。

## Competing Origin は何を意味するか

同じ prefix が複数の origin AS から見える状態は、観察として重要。

ただし、それだけで原因は決まらない。

- 意図したマルチホームや移行作業かもしれない。
- 誤設定かもしれない。
- route leak の一部として見えているかもしれない。
- prefix hijack の入口かもしれない。

BGP table だけでは「どの origin AS が許可されているか」は分からない。次のLabでは、RPKI origin validation を使ってこの問いを扱う。

## Route Leak との関係

RFC 7908 は route leak を、意図された範囲を超えて route advertisement が伝播してしまう問題として整理している。

Lab 03 では route leak の分類そのものには踏み込まない。ここでは、route leak や hijack を理解する前段として、まず「同じ prefix に複数の origin AS が見える」状態を作る。

## Lab #3 では読まないが、後で読む場所

| RFC | 後で扱うテーマ |
|---|---|
| RFC 6482 | ROA がどの AS に prefix origination を許可するか |
| RFC 6811 | BGP route と VRP を照合する origin validation |
| RFC 8210 | validated cache から router へ VRP を渡すRTR protocol |

## よくある誤解

- AS_PATH は ownership proof ではない。
- best path だけを見れば十分、とは限らない。
- competing origin は必ず攻撃という意味ではない。
- route leak と prefix hijack は同じ言葉ではない。
- RPKI origin validation は origin の検証であり、AS_PATH 全体の検証ではない。

## 次の Lab につながる問い

- `203.0.113.0/24` を originate してよい AS はどれか。
- その許可情報をROAではどう表すのか。
- BGP route の origin AS と、ROA/VRP の AS が一致しないと何が起きるか。
