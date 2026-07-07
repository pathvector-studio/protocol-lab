# Multicast and IGMP Reading Guide for Lab 29

This guide points at the material that matters for Lab 29. IP multicast is defined across a small family of RFCs: the host model and group addressing, plus IGMP for how a host tells the network it wants a group.

日本語: この guide は Lab 29 の読みどころを整理したものです。IP multicast は「host model と group アドレス」+「host が group を欲しいと網に伝える IGMP」という小さな RFC 群で定義されます。

Target material:

- [RFC 1112: Host Extensions for IP Multicasting](https://www.rfc-editor.org/rfc/rfc1112) — the host model, class D addresses, IP→MAC mapping
- [RFC 2236: Internet Group Management Protocol, Version 2](https://www.rfc-editor.org/rfc/rfc2236) — IGMPv2 membership reports and queries
- [RFC 3376: Internet Group Management Protocol, Version 3](https://www.rfc-editor.org/rfc/rfc3376) — IGMPv3 (source filtering); this is what Linux sends by default

## Reading Goal

Read multicast as *one send, delivered to a group*. The sender does not know or count the receivers; it puts one packet onto the segment addressed to a group, and every host that has *joined* that group receives it. IGMP is the signalling by which a host joins.

日本語: multicast は「1回の送信を group へ配る」ものとして読みます。sender は receiver を知らず数えもしない——group 宛の1パケットをセグメントに置き、その group に *join* した全 host が受け取る。IGMP は host が join するための signalling。

Start with these ideas:

- A **multicast group** is an IP in the class D range (224.0.0.0/4). It names a group, not a host.
- A host **joins** a group; the network then delivers that group's traffic to it.
- On Ethernet, an IPv4 multicast address maps to a MAC starting `01:00:5e`.
- **IGMP** is how a host tells its local router/switch "I want this group."

## Lab #29 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | RFC 1112 §4, §6.4 | class D address、host が join/leave する model、IP→MAC の対応 |
| 2 | RFC 3376 §4 | IGMPv3 membership report(Linux が既定で送る) |
| 3 | RFC 2236 | IGMPv2 の query/report(より単純な原型) |

## multicast group アドレス(class D)

RFC 1112 §4。

- **224.0.0.0 – 239.255.255.255**(224.0.0.0/4)が multicast。先頭4bit が `1110`。
- host アドレスではなく **group** を表す。送信側は group 宛に1回送る。
- 用途別に区分がある:
  - `224.0.0.0/24` は **link-local control**(ルーティングプロトコル等)。TTL 1 で外に出ない。例: `224.0.0.22` = IGMPv3。
  - `239.0.0.0/8` は **administratively scoped**(組織内ローカル、RFC 2365)。Lab で使う `239.1.1.1` はここ。

## IP → MAC の対応

RFC 1112 §6.4。

- IPv4 multicast は Ethernet の **`01:00:5e`** で始まる MAC に写す。
- IP の下位23bit を MAC の下位23bit にコピーする(`01:00:5e:0x:xx:xx`)。
- だから `239.1.1.1` はキャプチャで `01:00:5e:01:01:01` として見える。
- 上位ビットが落ちるので 32:1 の衝突があるが、実用上は問題になりにくい。

## IGMP(join を網に伝える)

RFC 2236 / RFC 3376。

- host が group に join すると、**membership report** を送る(「この group が欲しい」)。
- router は定期的に **membership query** を送り、まだ誰か聞いているか確かめる。
- 誰もいなくなれば router はその group の転送を止める(または leave message で早める)。
- Linux は既定で **IGMPv3** を送る。report の宛先は `224.0.0.22`、MAC は `01:00:5e:00:00:16`。

## switch と IGMP snooping

- 素の L2 switch(や Linux bridge)は multicast を **broadcast のように全ポートへ flood** する。
- **IGMP snooping** を有効にすると、switch は IGMP report を覗き見て、その group を聞いているポートにだけ転送する(帯域の節約)。
- Lab の bridge は `mcast_snooping 0`(flood)にしてある。狙いは「membership の signalling(IGMP)」と「1コピーが全 receiver に届く」ことを素直に観察するため。

## unicast / broadcast / multicast

| | 宛先 | 届く範囲 | コピー数 |
|---|---|---|---|
| unicast | 1つの host | 1つ | receiver ごとに1(N人なら N回送信) |
| broadcast | セグメント全体 | 全 host(要否問わず) | セグメントに1 |
| multicast | group | join した host のみ | セグメントに1 |

- multicast は broadcast の「セグメントに1コピー」と、unicast の「欲しい人だけ」の良いとこ取り。
- N 人の receiver に対し、sender は依然 **1回だけ**送る。これが「one send, many receivers」。

## Message から読む(Lab の出力)

| 見えるもの | 意味 |
|---|---|
| `10.0.0.2 > 224.0.0.22: igmp v3 report` | receiver が group に join した membership report |
| `01:00:5e:00:00:16` | IGMPv3 report の宛先 MAC |
| `10.0.0.1 > 239.1.1.1: UDP` / `01:00:5e:01:01:01` | sender の multicast データ(group 宛の1コピー) |
| `ip maddr show` に `239.1.1.1` | その interface が group に join している |
| receiver 双方が `0/513 (0%)` | 1本の stream を両者が受信(コピー増やさず) |

## よくある誤解

- multicast を「同じ unicast を N 回送る」ことと混同する。実際はセグメントに **1コピー**。
- group アドレスを host アドレスと思う。class D は group を指す。
- IGMP が「データを運ぶ」と思う。IGMP は **join の signalling** だけ。データは UDP 等で別に流れる。
- switch が賢く配ると思い込む。snooping 無しの L2 は **flood**。賢い転送は IGMP snooping が要る。
- TTL を忘れる。`224.0.0.0/24`(link-local control)は TTL 1 で外に出ない。

## 前後の Lab とのつながり

- broadcast/ARP(Lab 24)や NDP(Lab 23)と同じ「1対多の配送」だが、multicast は *join した集合* にだけ届く。
- IPv6 NDP(Lab 23)は solicited-node multicast を使う——IPv6 は broadcast を廃し multicast に統一した。
- bridge/VLAN(Lab 26)や VXLAN(Lab 18)の L2 セグメント理解が土台になる。
