# RFC 4271 Reading Guide: BGP-4

This guide helps you read the parts of RFC 4271 that matter for BGP Lab 01. It is meant to be used alongside the RFC, not instead of it.

日本語: この guide は、BGP Lab 01 に必要な RFC 4271 の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFC: [RFC 4271: A Border Gateway Protocol 4 (BGP-4)](https://www.rfc-editor.org/rfc/rfc4271)

## Reading Goal

For the first lab, read BGP as a protocol that exchanges prefixes and path attributes between ASNs. The theme is one prefix announcement to a route you can explain.

You do not need the full FSM, every path attribute, or the complete decision process yet. Start with these ideas:

日本語: 最初のLabでは、BGPを「AS間でprefixとpath attributesを交換する仕組み」として読みます。FSM、全属性、経路選択の詳細にはまだ踏み込みません。まず以下を理解します。

- AS は BGP で見たときの管理単位である。
- prefix は到達先の集合を表す。
- route は「prefix + path attributes」の組である。
- UPDATE message が経路広告と取り消しを運ぶ。
- AS_PATH は、その到達性情報が通ってきた AS の列を表す。
- NEXT_HOP は、その prefix へ転送するときに次に向かうべきルータを表す。

## Lab #1 で読む場所

| 優先 | RFC 4271 の章 | 読む目的 |
|---|---|---|
| 1 | 1.1 Definition of Commonly Used Terms | AS、BGP speaker、EBGP/IBGP、NLRI、Route、RIB の用語をそろえる |
| 2 | 3 Summary of Operation | BGP が「network reachability information」を交換するプロトコルであることをつかむ |
| 3 | 3.1 Routes: Advertisement and Storage | route が prefix と path attributes の組であること、UPDATE で広告されることを読む |
| 4 | 4.1 Message Header Format | BGP message には type があり、UPDATE が type 2 であることを確認する |
| 5 | 4.2 OPEN Message Format | My Autonomous System と BGP Identifier を観察対象にする |
| 6 | 4.3 UPDATE Message Format | Withdrawn Routes、Path Attributes、NLRI の配置を見る |
| 7 | 5 Path Attributes | ORIGIN、AS_PATH、NEXT_HOP が mandatory attribute であることを確認する |
| 8 | 5.1.1 ORIGIN | originating speaker が作る属性として読む |
| 9 | 5.1.2 AS_PATH | eBGP で自ASを prepend する動きを読む |
| 10 | 5.1.3 NEXT_HOP | advertised prefix への next hop の意味を読む |

## 最初に押さえる用語

### Autonomous System

RFC 4271 では、AS は外部から見ると一貫した routing plan を持つ管理単位として扱われる。Lab では `AS65001` と `AS65002` を別組織のように扱い、eBGP neighbor を張る。

ポイント:

- 同じ AS 内の BGP は IBGP。
- 異なる AS 間の BGP は EBGP。
- Lab #1 は EBGP だけを扱う。

### Prefix / NLRI

Prefix は `203.0.113.0/24` のような到達先アドレス範囲。RFC 4271 の UPDATE message では、到達先 prefix は NLRI として運ばれる。

Lab #1 では、`AS65001` が `203.0.113.0/24` を広告し、`AS65002` がそれを BGP table に入れるところを見る。

### Route

RFC 4271 では route は、ざっくり言うと以下の組。

```text
route = destinations(prefix/NLRI) + path attributes
```

つまり BGP が交換しているのは「IP prefix だけ」ではない。prefix に対して、AS_PATH、NEXT_HOP、ORIGIN などの属性が付く。

Lab #1 の観察対象:

```text
203.0.113.0/24
  ORIGIN: IGP
  AS_PATH: 65001
  NEXT_HOP: 10.0.0.1
```

## UPDATE message の読み方

RFC 4271 Section 4.3 は、UPDATE message を次の塊で説明している。

```text
Withdrawn Routes Length
Withdrawn Routes
Total Path Attribute Length
Path Attributes
Network Layer Reachability Information
```

Lab #1 は「広告」を見るので、まず注目するのは `Path Attributes` と `NLRI`。

読み方:

- `NLRI`: どの prefix へ到達できると言っているか。
- `Path Attributes`: その prefix にどんな経路属性が付くか。
- `Withdrawn Routes`: 以前広告した prefix を取り消すときに使う。Lab #2 以降で扱う。

## Path attributes の最小セット

RFC 4271 Section 5 では、UPDATE に NLRI が入る場合、ORIGIN、AS_PATH、NEXT_HOP が well-known mandatory attribute として扱われる。

### ORIGIN

ORIGIN は、その経路情報の起源を表す属性。Lab #1 では FRRouting の `network` 文で originate した prefix が `i` または `IGP` として表示されることを確認する。

ここでの `IGP` は「OSPF や IS-IS で学んだ」という意味ではなく、BGP の ORIGIN attribute の値。

### AS_PATH

AS_PATH は、UPDATE の routing information が通ってきた AS を表す。

Lab #1 の期待:

```text
AS65001 が 203.0.113.0/24 を AS65002 に広告する
AS65002 から見ると AS_PATH は 65001
```

次の Lab では、`AS65001 -> AS65002 -> AS65003` のように 3 AS にして、AS_PATH が `65002 65001` のように伸びる様子を見る。

### NEXT_HOP

NEXT_HOP は、NLRI に載っている宛先へ転送するときに使う次ホップアドレス。

Lab #1 の eBGP 直結構成では、`AS65002` から見た `203.0.113.0/24` の NEXT_HOP は `AS65001` 側のリンクアドレスになる。

注意:

- NEXT_HOP は「最終宛先」ではない。
- NEXT_HOP は「AS番号」でもない。
- forwarding では、NEXT_HOP をさらに routing table で解決する。

## Lab #1 では読まないが、後で読む場所

| RFC 4271 の章 | 後で扱うテーマ |
|---|---|
| 3.2 Routing Information Base | Adj-RIB-In、Loc-RIB、Adj-RIB-Out を BGP table と対応させる |
| 4.4 KEEPALIVE Message Format | neighbor 維持、Hold Timer、keepalive |
| 4.5 NOTIFICATION Message Format | neighbor が落ちる理由、エラーコード |
| 6 BGP Error Handling | malformed UPDATE、missing attribute |
| 8 BGP Finite State Machine | Idle、Connect、Active、OpenSent、OpenConfirm、Established |
| 9 UPDATE Message Handling | 経路選択、degree of preference、広告判断 |

## よくある誤解

- BGP は「最短経路」を自動で選ぶプロトコルではない。AS_PATH 長は経路選択要素の1つだが、local policy が強い。
- BGP が運ぶ prefix は「そのASが所有している証明」ではない。RPKI/ROV はこの問題に関係する。
- AS_PATH に自ASが含まれている経路は loop の疑いがある。これは BGP hijack や誤広告を理解する前の大事な入口になる。
- `203.0.113.0/24` はドキュメント用 prefix なので、実インターネットへ流してはいけない。Lab では閉じた環境で使う。

## PathVector Studio の公開教材へのつながり

PathVector Studio の BGP/RPKI learning track では、最初に「ある prefix に対して、誰が、どんな AS_PATH で、どの origin AS として広告しているか」を自分で説明できる状態を作る。

Lab #1 では、1つの prefix 広告を手元で作り、BGP table と UPDATE の中身を対応づける。

## 次の Lab につながる問い

- `203.0.113.0/24` を取り消すと UPDATE はどう変わるか。
- AS を3つに増やすと AS_PATH はどう伸びるか。
- 同じ prefix を2つの AS が広告したら、受信側は何を見るべきか。
- RPKI では、どの AS がその prefix を originate してよいかをどう表すのか。
