# RFC 4271 Reading Guide for BGP Lab 02

This guide helps you read the parts of RFC 4271 that matter for BGP Lab 02. It is meant to be used alongside the RFC, not instead of it.

日本語: この guide は、BGP Lab 02 に必要な RFC 4271 の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFC: [RFC 4271: A Border Gateway Protocol 4 (BGP-4)](https://www.rfc-editor.org/rfc/rfc4271)

## Reading Goal

For this lab, read BGP UPDATE as the message that changes reachability. The same message type can announce a route and withdraw a route.

日本語: このLabでは、BGP UPDATE を「到達性を変化させる message」として読みます。同じ UPDATE message が、route の広告にも取り下げにも使われます。

Start with these ideas:

- A route can be announced with NLRI and path attributes.
- A route can be withdrawn with Withdrawn Routes.
- NEXT_HOP, AS_PATH, and ORIGIN explain an announced route.
- A withdrawal identifies the prefix being removed.
- A BGP session can stay Established while a route appears or disappears.

## Lab #2 で読む場所

| 優先 | RFC 4271 の章 | 読む目的 |
|---|---|---|
| 1 | 3.1 Routes: Advertisement and Storage | route が UPDATE で広告され、withdraw されることを読む |
| 2 | 4.3 UPDATE Message Format | Withdrawn Routes、Path Attributes、NLRI の配置を見る |
| 3 | 5 Path Attributes | NLRI がある UPDATE に mandatory attributes が必要なことを確認する |
| 4 | 5.1.1 ORIGIN | announced route の ORIGIN を読む |
| 5 | 5.1.2 AS_PATH | announced route の AS_PATH を読む |
| 6 | 5.1.3 NEXT_HOP | announced route の NEXT_HOP を読む |

## UPDATE message の3つの場所

RFC 4271 Section 4.3 では、UPDATE message を次の大きな部分で説明している。

```text
Withdrawn Routes Length
Withdrawn Routes
Total Path Attribute Length
Path Attributes
Network Layer Reachability Information
```

Lab 02 では、このうち2つの使い方を見る。

### Announcement

`r1` が `203.0.113.0/24` を広告するとき、見る場所は主にここ。

```text
Path Attributes:
  ORIGIN
  AS_PATH
  NEXT_HOP

NLRI:
  203.0.113.0/24
```

読み方:

- `NLRI`: どの prefix へ到達できると言っているか。
- `ORIGIN`: route の origin type。
- `AS_PATH`: その reachability information が通ってきた AS。
- `NEXT_HOP`: その prefix に転送するとき次に向かう IP address。

### Withdrawal

`r1` が `203.0.113.0/24` を取り下げるとき、見る場所は主にここ。

```text
Withdrawn Routes:
  203.0.113.0/24
```

読み方:

- withdrawal は、以前広告された prefix を取り下げる。
- withdrawal は、その prefix の NEXT_HOP や AS_PATH を再説明するための message ではない。
- 受信側は該当 route を BGP table から消す。

## NEXT_HOP はどこで効くか

Lab 02 では NEXT_HOP を2つの場面で区別する。

Announcement:

```text
203.0.113.0/24 via 10.0.0.1
```

このとき `10.0.0.1` が NEXT_HOP。

Withdrawal:

```text
Withdrawn Routes: 203.0.113.0/24
```

このとき重要なのは、どの prefix を取り下げたか。withdraw は「NEXT_HOP を変える」message ではなく、「この route を消す」message として読む。

## Lab #2 では読まないが、後で読む場所

| RFC 4271 の章 | 後で扱うテーマ |
|---|---|
| 3.2 Routing Information Base | Adj-RIB-In、Loc-RIB、Adj-RIB-Out |
| 4.4 KEEPALIVE Message Format | session が維持される仕組み |
| 4.5 NOTIFICATION Message Format | session が落ちる理由 |
| 8 BGP Finite State Machine | Established 以外の neighbor state |
| 9 UPDATE Message Handling | 複数経路、経路選択、広告判断 |

## よくある誤解

- withdraw は TCP session close ではない。BGP session は維持されたまま、route だけが消える。
- withdraw は「別の悪い route を送る」ことではない。取り下げる prefix を Withdrawn Routes に載せる。
- `NEXT_HOP` は announcement の path attribute。withdraw の主役は Withdrawn Routes。
- BGP table に route がないことは、その prefix が世界中で存在しないことを意味しない。このLabでは r2 が r1 からその route を学ばなくなっただけ。

## 次の Lab につながる問い

- 同じ `203.0.113.0/24` を別の AS も広告したら、r2 は何を見るべきか。
- AS_PATH が異なる2つの route があるとき、どの情報が比較対象になるか。
- origin AS が期待と違うかどうかを、RPKI ではどう判断するのか。
