# RPKI Origin Validation Reading Guide for Lab 04

This guide helps you read the RFC sections that matter for RPKI Lab 04. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、RPKI Lab 04 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 6482: A Profile for Route Origin Authorizations (ROAs)](https://www.rfc-editor.org/rfc/rfc6482)
- [RFC 6811: BGP Prefix Origin Validation](https://www.rfc-editor.org/rfc/rfc6811)
- [RFC 8210: The Resource Public Key Infrastructure (RPKI) to Router Protocol, Version 1](https://www.rfc-editor.org/rfc/rfc8210)

## Reading Goal

For this lab, read RPKI origin validation as a comparison between a BGP route and validated authorization data.

日本語: このLabでは、RPKI origin validation を「BGP route と、検証済みの許可情報を照合する仕組み」として読みます。

Start with these ideas:

- A BGP route has a prefix and an origin AS.
- A ROA says which AS is authorized to originate a prefix, up to a maximum prefix length.
- A router usually does not process raw ROAs directly. It receives validated data from a cache.
- A VRP is the validated prefix/origin information used for route origin validation.
- Origin validation produces `valid`, `invalid`, or `not found`.

## Lab #4 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 6811 | 2 | route、origin AS、VRP、covering prefix の用語をそろえる |
| 2 | RFC 6811 | 2.1 | valid / invalid / not found の判定を読む |
| 3 | RFC 6482 | 3 | ROA が AS と IP prefix をどう表すかを読む |
| 4 | RFC 8210 | 1 | router と cache を分けて考える |
| 5 | RFC 8210 | 2 | RTR protocol が validated cache から router へ情報を運ぶことを読む |

## ROA と VRP

ROA と VRP は同じものではない。

ROA は、RPKI repository に置かれる署名された object。どの AS がどの prefix を originate してよいかを表す。

VRP は、ROA などを検証した結果として router が使う prefix/origin data。Lab 04 では、local StayRTR cache が次の VRP を配る。

```text
prefix:     203.0.113.0/24
max length: 24
origin AS:  65001
```

このLabでは実RPKI repository を同期しない。ROAの検証過程ではなく、router が VRP を受け取った後の origin validation を観察する。

## Origin Validation の3状態

RFC 6811 の中心は、BGP route と VRP を比べて validation state を決めるところ。

Lab 04 の対応はこうなる。

| BGP route | VRPとの関係 | State |
|---|---|---|
| `203.0.113.0/24`, origin AS65001 | prefix と AS が一致する | `valid` |
| `203.0.113.0/24`, origin AS65003 | prefix は covered、AS が不一致 | `invalid` |
| `198.51.100.0/24`, origin AS65004 | covering VRP がない | `not found` |

`not found` は、まだ判断材料がない状態。`invalid` とは違う。

## maxLength の読み方

ROA/VRP には prefix と max length がある。

```text
203.0.113.0/24, maxLength 24, AS65001
```

この場合、許可されるのは `203.0.113.0/24` だけ。もし max length が `25` なら、`203.0.113.0/25` や `203.0.113.128/25` も prefix length の範囲としては許可対象になる。

Lab 04 は max length を `24` に固定し、origin AS の一致・不一致に集中する。

## RTR Cache の役割

RFC 8210 は、validated cache と router の間の protocol を扱う。

このLabの `stayrtr` container は local RTR cache として動く。`r2` は FRRouting の RPKI module を使って `10.0.25.2:8282` に接続し、VRP を受け取る。

```text
StayRTR local cache -> RTR protocol -> r2 / FRRouting
```

ここで観察するのは、public RPKI の取得や検証ではなく、router が validated data を受け取って BGP route に state を付ける部分。

## BGP と RPKI の境界

RPKI origin validation は、BGP UPDATE を置き換えるものではない。

BGP route は BGP neighbor から届く。RPKIの VRP は RTR cache から届く。router はこの2つを照合する。

重要な境界:

- BGP は reachability information を運ぶ。
- RPKI origin validation は origin AS の許可を判定する。
- AS_PATH 全体が正しいかどうかは、このLabの範囲では検証しない。
- `invalid` と判定された route をどう扱うかは routing policy の仕事。

## よくある誤解

- ROA と VRP は同じものではない。
- `not found` は `invalid` ではない。
- RPKI origin validation は AS_PATH 全体の検証ではない。
- `invalid` route は、policy なしで必ず消えるわけではない。
- local JSON で作った VRP は、このLabのための閉じた実験データ。

## 次の Lab につながる問い

- `invalid` route を reject する policy はどう書くのか。
- max length を変えると validation state はどう変わるのか。
- 実際のRPKI repository と local lab の間には、どんな運用上の違いがあるのか。

