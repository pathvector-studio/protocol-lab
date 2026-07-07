# IPv6 Neighbor Discovery Reading Guide for Lab 23

This guide helps you read the RFC sections that matter for Lab 23. It is meant to be used alongside the RFCs, not instead of them.

日本語: この guide は、Lab 23 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFCs:

- [RFC 4861: Neighbor Discovery for IPv6](https://www.rfc-editor.org/rfc/rfc4861)
- [RFC 4291: IPv6 Addressing Architecture](https://www.rfc-editor.org/rfc/rfc4291)

## Reading Goal

For this lab, read Neighbor Discovery as *ARP re-done on ICMPv6 with multicast*: the same IP-to-MAC resolution, but more targeted and folded into ICMPv6.

日本語: このLabでは、Neighbor Discovery を「ARP を ICMPv6 と multicast でやり直したもの」として読みます。同じ IP→MAC 解決を、より的を絞って、ICMPv6 の枠組みで行う。

Start with these ideas:

- A host needs a neighbor's MAC to deliver a frame on the same link.
- IPv6 does this with ICMPv6 Neighbor Solicitation / Advertisement, not ARP.
- The solicitation goes to a solicited-node multicast address, not broadcast.

## Lab #23 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 4861 | 4.3 | Neighbor Solicitation の形式(ICMPv6 type 135) |
| 2 | RFC 4861 | 4.4 | Neighbor Advertisement の形式(type 136、flags) |
| 3 | RFC 4861 | 7.2 | address resolution の手順(NS→NA→cache) |
| 4 | RFC 4291 | 2.7.1 | solicited-node multicast の作り方 |
| 5 | RFC 4861 | 7.3.2 | neighbor cache の状態遷移 |

## ARP と NDP

- どちらも目的は同じ: **IP アドレス → MAC アドレス** の解決(同一リンク)。
- ARP(IPv4)は専用の EtherType を持つ独立プロトコルで、**broadcast** で全員に聞く。
- NDP(IPv6)は **ICMPv6** のメッセージ群(type 133-137)で、**solicited-node multicast** で的を絞る。
- IPv6 には broadcast が無い。すべて multicast で置き換えられている。

## Neighbor Solicitation / Advertisement

RFC 4861 4.3-4.4。

- **Neighbor Solicitation(NS, type 135)**: 「このアドレスの持ち主は?」。相手の solicited-node multicast 宛て。自分の MAC を option で載せることが多い。
- **Neighbor Advertisement(NA, type 136)**: 「私です、MAC はこれ」。flags:
  - **Solicited**: NS への応答であること。
  - **Override**: 受け手の既存 cache を上書きしてよいこと。
  - **Router**: 送信者がルータであること。
- address resolution 以外に、リンク層アドレス変更の通知(unsolicited NA)などにも使う。

## solicited-node multicast

RFC 4291 2.7.1。

- 相手アドレスの **下位 24bit** を、プレフィックス `ff02::1:ff00:0/104` に付けて作る。
  - 例: `2001:db8:23::2` → `ff02::1:ff00:2`。
- L2 の multicast MAC は `33:33:` + IPv6 multicast の下位 32bit → `33:33:ff:00:00:02`。
- この multicast を listen しているのは、下位 24bit が一致するごく少数のホストだけ。だから broadcast のように全員を起こさない。

## neighbor cache

RFC 4861 7.3。IPv4 の ARP テーブルに相当(`ip -6 neigh`)。

| 状態 | 意味 |
|---|---|
| INCOMPLETE | 解決中(NS 送信済み、NA 待ち) |
| REACHABLE | 最近、到達確認できた |
| STALE | しばらく使っていない(次の送信時に確認しうる) |
| DELAY / PROBE | 再確認の途中 |

- 一度解決したら cache を使い、毎回 solicitation はしない。TTL 的に古くなると再確認する。

## NDP の他の仕事

NDP は address resolution だけではない(RFC 4861 全体):

- **Router discovery**: Router Solicitation(133)/ Advertisement(134)。プレフィックスや default router を配る(SLAAC の土台、RFC 4862)。
- **Duplicate Address Detection(DAD)**: アドレス割当時、自分宛ての NS を出して重複を確認。
- **Redirect(137)**: より良い next-hop を教える。

このLabは resolution に集中したが、すべて同じ ICMPv6 の枠組み。

## Message から読む

Lab の capture を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `> ff02::1:ff00:2 ... neighbor solicitation, who has ::2` | solicited-node multicast への NS |
| `33:33:ff:00:00:02`(宛先 MAC) | solicited-node multicast の L2 アドレス |
| `neighbor advertisement, Flags [solicited, override]` | NS への応答、cache 上書き可 |
| `ip -6 neigh`: `::2 lladdr <MAC> REACHABLE` | 解決済みの neighbor cache |

## よくある誤解

- NDP と ARP は別物ではない。役割は同じ、手段が違う。
- IPv6 に broadcast は無い。solicited-node multicast を使う。
- NS は全員宛てではない。的を絞った multicast。
- cache は永続ではない。状態が遷移し、再確認する。
- NDP は resolution 以外(RA/DAD/Redirect)も担う。

## 前後の Lab とのつながり

- Lab 22(DHCP)は IPv4 のアドレス取得。IPv6 では SLAAC(RA ベース)や DHCPv6 が対応。
- NDP は VXLAN/GRE(Lab 18/21)などの下でも、リンク上の MAC 解決として動く。
- multicast の使い方は、IPv6 全体(RA, DAD, MLD)の理解の土台。
