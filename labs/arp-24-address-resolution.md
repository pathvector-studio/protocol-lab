# Lab #24: ARP — the IPv4 Original

Expected time: 35 to 50 minutes  
日本語: 想定時間 35〜50分

Reading guide: [`../rfc-notes/arp-address-resolution.md`](../rfc-notes/arp-address-resolution.md)

Prerequisites: [Lab 23: IPv6 Neighbor Discovery](ndp-23-neighbor-discovery.md), [TCP Lab 07](tcp-07-handshake-teardown.md)

## Goal

Lab 23 showed how IPv6 finds a neighbor's MAC. This lab shows the **IPv4 original** that it replaced: **ARP** (Address Resolution Protocol). Same job — turn an IP address into the MAC address needed to actually deliver a frame — but ARP does it by **broadcasting** to everyone on the link.

You will watch the resolution:

- two IPv4 nodes share a link (`10.0.0.1` and `10.0.0.2`),
- with the ARP cache cleared, `node-a` pings `node-b`,
- `node-a` **broadcasts** an ARP request — "who has `10.0.0.2`? tell `10.0.0.1`" — to `ff:ff:ff:ff:ff:ff`,
- `node-b` sends a **unicast** ARP reply — "`10.0.0.2` is at `aa:...:b2`",
- `node-a`'s ARP table now maps `10.0.0.2 → MAC`.

日本語: Lab 23 は IPv6 が近隣の MAC をどう見つけるかを見ました。この Lab はそれが置き換えた **IPv4 の原型**、**ARP**(Address Resolution Protocol)です。仕事は同じ(IP → MAC 解決)ですが、ARP はリンク上の全員に **broadcast** して聞きます。ARP cache をクリアしてから node-a が node-b に ping し、node-a が `ff:ff:ff:ff:ff:ff` へ ARP request「`10.0.0.2` は誰? `10.0.0.1` に教えて」を broadcast し、node-b が unicast の ARP reply「`10.0.0.2` は `aa:...:b2`」を返し、ARP table に `::2 → MAC` が入る、という解決を観察します。

By the end, you should be able to complete this comparison (with Lab 23):

| | ARP (this lab, IPv4) | NDP (Lab 23, IPv6) |
|---|---|---|
| "who has X?" sent to | **broadcast** (everyone) | solicited-node multicast (few) |
| Protocol | its own EtherType `0x0806` | ICMPv6 |
| Request / Reply | ARP request / reply | Neighbor Solicitation / Advertisement |
| Cache | ARP table (`ip neigh`) | neighbor cache (`ip -6 neigh`) |

## What You Will Learn

理解したいこと:

- Why an IP address alone cannot deliver a frame on a link — you need the MAC.
- How ARP resolves IP → MAC with a broadcast request and a unicast reply.
- What the ARP request and reply carry ("who-has", "is-at").
- Where the ARP cache lives (`ip neigh`) and why it exists.
- Why broadcast is simple but less efficient than NDP's multicast.

This lab does not cover:

- Gratuitous ARP, ARP probe/announce (RFC 5227), or proxy ARP.
- ARP spoofing / security.
- RARP or the historical BOOTP relationship.

日本語: IP アドレスだけでは配送できず MAC が要る理由、ARP が broadcast request + unicast reply で解決する仕組み、request/reply の中身(who-has/is-at)、ARP cache(`ip neigh`)の役割、broadcast が単純だが NDP の multicast より非効率な理由を学びます。

## RFCで読む場所

| RFC | 章 | 読むポイント |
|---|---|---|
| RFC 826 | 全体 | ARP のパケット形式と解決アルゴリズム(短い) |
| RFC 826 | "Packet format" | hardware/protocol type、op(1=request, 2=reply) |
| RFC 1122 | 2.3.2 | ARP cache の扱い(ホスト要件) |

## 実験の全体像

IPv4 を付けた2ノードを1本のリンクで繋ぐ。

```text
node-a 10.0.0.1/24 ==== eth1/eth1 ==== node-b 10.0.0.2/24
```

node-a の ARP cache をクリアしてから ping すると、ARP による解決が走る。

```mermaid
sequenceDiagram
  participant A as node-a (10.0.0.1)
  participant BC as broadcast<br/>ff:ff:ff:ff:ff:ff
  participant B as node-b (10.0.0.2)

  Note over A: cache cleared; wants 10.0.0.2's MAC
  A->>BC: ARP request "who has 10.0.0.2? tell 10.0.0.1"
  Note over B: that's me
  B->>A: ARP reply "10.0.0.2 is-at aa:...:b2" (unicast)
  Note over A: ARP table: 10.0.0.2 -> aa:...:b2
```

`10.0.0.0/24` はローカル閉域。

## 必要なもの

推奨環境:

- Linux / WSL2 / Linux VM
- Docker
- containerlab

使用イメージ:

- `nicolaka/netshoot:latest`（`ip`、`ping`、`tcpdump`(ARP デコード) 同梱）

追加イメージは不要。

## 実行手順

```bash
./scripts/labctl.sh run arp-24
```

### 1. 作業ディレクトリへ移動する

```bash
cd protocol-lab/examples/arp-24
```

### 2. 起動する

```bash
sudo containerlab deploy -t arp-24.clab.yml
```

### 3. ARP cache をクリアして、解決を観察する

```bash
docker exec clab-arp-24-node-a ip neigh flush all
docker exec -d clab-arp-24-node-a tcpdump -i eth1 -n -e "arp"
docker exec clab-arp-24-node-a ping -c2 10.0.0.2
docker exec clab-arp-24-node-a pkill -INT tcpdump
docker exec clab-arp-24-node-a tcpdump -n -e -vv -r /tmp/arp.pcap
```

見るポイント:

```text
aa:...:e2 > ff:ff:ff:ff:ff:ff, ARP, Request who-has 10.0.0.2 tell 10.0.0.1
aa:...:b2 > aa:...:e2, ARP, Reply 10.0.0.2 is-at aa:...:b2
```

### 4. ARP table を見る

```bash
docker exec clab-arp-24-node-a ip neigh show dev eth1
```

```text
10.0.0.2 lladdr aa:c1:ab:97:55:b2 REACHABLE
```

## 期待出力

- `ping 10.0.0.2` が成功。
- capture: `Request who-has 10.0.0.2 tell 10.0.0.1`(宛先 `ff:ff:ff:ff:ff:ff`)と `Reply 10.0.0.2 is-at <MAC>`。
- `ip neigh`: `10.0.0.2 lladdr <MAC> REACHABLE`。

## なぜそう動くのか

同じリンク上でフレームを届けるには、宛先の **MAC アドレス** が要る。IP アドレスは「どのホストか」を示すが、Ethernet はフレームを MAC で配送するからだ。この「IP → MAC」を IPv4 では ARP が解決する。

- **broadcast request**: node-a は node-b の MAC を知らない。だから宛先を `ff:ff:ff:ff:ff:ff`(broadcast)にして「`10.0.0.2` は誰? `10.0.0.1` に教えて」を全員に送る。リンク上の全ホストがこれを受け取る。
- **unicast reply**: 該当する node-b だけが「私です、MAC はこれ」と返す。request には送信者(node-a)の IP と MAC が入っているので、reply は node-a へ unicast できる(全員に返す必要はない)。
- **ARP cache**: 得た「IP → MAC」を cache する(`ip neigh`)。以後の通信はこの cache を使い、毎回 broadcast しない。エントリは古くなると再確認される。
- **NDP との違い(Lab 23)**: 役割は完全に同じ(IP→MAC)。違いは「聞き方」。ARP は broadcast で全員を起こす。NDP は相手の solicited-node multicast だけに送るので、無関係なホストを起こさない。IPv6 が broadcast を廃し multicast に統一したのは、この効率(と設計の整理)のため。

要点は、**Ethernet は MAC で配送するので、IP から MAC を引く仕組みが要る**こと。IPv4 はそれを broadcast の ARP で、IPv6 は multicast の NDP で行う。

## 詰まりやすい点

- **IP だけで届くと思う**。リンク上の配送は MAC。ARP でそれを引く。
- **request も reply も broadcast と思う**。request は broadcast、reply は unicast。
- **ARP がルータ越えでも使えると思う**。ARP は同一リンク(L2)内だけ。別セグメントの相手には、gateway の MAC を ARP で引く。
- **cache を忘れる**。一度引いたら cache する。毎回は聞かない。
- **NDP と役割が違うと思う**。役割は同じ。手段(broadcast vs multicast、独自 vs ICMPv6)が違う。

## 後片付け

```bash
sudo containerlab destroy -t arp-24.clab.yml --cleanup
```

`labctl.sh run arp-24` を使った場合は、スクリプトが最後に destroy する。

## 確認問題

1. 同じリンク上でフレームを届けるのに、IP アドレスの他に何が要るか。なぜか。
2. ARP request と reply は、それぞれ broadcast か unicast か。なぜそうできるか。
3. ARP request の "who-has" と "tell" は何を意味するか。
4. ARP cache には何が入るか。なぜ cache するか。
5. 別セグメント(ルータ越え)の相手に送るとき、ARP は誰の MAC を引くか。
6. ARP(IPv4)と NDP(IPv6)の違いを、聞き方の観点で説明せよ。

## References

- [RFC 826: An Ethernet Address Resolution Protocol](https://www.rfc-editor.org/rfc/rfc826)
- [RFC 1122: Requirements for Internet Hosts — Communication Layers](https://www.rfc-editor.org/rfc/rfc1122)
- [RFC 5227: IPv4 Address Conflict Detection](https://www.rfc-editor.org/rfc/rfc5227)
- [RFC 5737: IPv4 Address Blocks Reserved for Documentation](https://www.rfc-editor.org/rfc/rfc5737)

## 検証済み実行ログ (2026-07-07)

このLabは実機で再現性を確認済みです。

実行環境:

- Ubuntu 26.04 LTS (kernel 7.0.0-27-generic, x86_64)
- Docker 29.1.3
- containerlab 0.77.0
- node-a / node-b: `nicolaka/netshoot:latest`（tcpdump 同梱）

`PATH="/tmp/pl-shim:$PATH" ./scripts/labctl.sh run arp-24` で deploy → verify → destroy を実行し、`verification.json` は `"status": "verified"` を返した。

### ARP request(broadcast)→ reply(unicast)

```text
$ docker exec clab-arp-24-node-a tcpdump -n -e -vv -r arp.pcap
aa:c1:ab:10:4e:e2 > ff:ff:ff:ff:ff:ff, ethertype ARP (0x0806) ...
    Request who-has 10.0.0.2 tell 10.0.0.1, length 28
aa:c1:ab:97:55:b2 > aa:c1:ab:10:4e:e2, ethertype ARP (0x0806) ...
    Reply 10.0.0.2 is-at aa:c1:ab:97:55:b2, length 28
```

request は `ff:ff:ff:ff:ff:ff`(broadcast)へ、「`10.0.0.2` は誰? `10.0.0.1` に教えて」。該当する node-b だけが unicast で「`10.0.0.2` は `aa:c1:ab:97:55:b2`」と返す。

### 解決後の ARP table

```text
$ docker exec clab-arp-24-node-a ip neigh show dev eth1
10.0.0.2 lladdr aa:c1:ab:97:55:b2 REACHABLE
```

`10.0.0.2` が MAC 付きで cache に入り `REACHABLE`。以後はこの cache を使う。

Lab 23(NDP)と並べると、役割は同じ「IP→MAC」で、ARP は broadcast(全員)、NDP は solicited-node multicast(該当者だけ)という聞き方の違いが見える。IPv6 が broadcast を廃した理由がここにある。

### Cleanup

```bash
containerlab destroy -t arp-24.clab.yml --cleanup
```
