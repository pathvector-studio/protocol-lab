# Lab #23: IPv6 Neighbor Discovery — ARP's Successor

Expected time: 40 to 55 minutes  
日本語: 想定時間 40〜55分

Reading guide: [`../rfc-notes/ndp-neighbor-discovery.md`](../rfc-notes/ndp-neighbor-discovery.md)

Prerequisite: [TCP Lab 07](tcp-07-handshake-teardown.md) (reading captures)

## Goal

To send a packet to a neighbor on the same link, a host needs that neighbor's **MAC address**. On IPv4 that job is ARP. On IPv6 it is **Neighbor Discovery (NDP)** — the same idea, but done with **ICMPv6** and **multicast** instead of broadcast.

This lab watches the resolution happen:

- two IPv6 nodes share a link (`2001:db8:23::1` and `::2`),
- with the neighbor cache cleared, `node-a` pings `node-b`,
- `node-a` sends a **Neighbor Solicitation** (ICMPv6 type 135) to `node-b`'s **solicited-node multicast** address — "who has `2001:db8:23::2`?",
- `node-b` replies with a **Neighbor Advertisement** (type 136) carrying its MAC,
- `node-a`'s neighbor table now maps `2001:db8:23::2 → MAC`.

日本語: 同じリンク上の相手にパケットを送るには、相手の **MAC アドレス** が要ります。IPv4 ではそれが ARP。IPv6 では **Neighbor Discovery(NDP)** が同じ仕事を、broadcast ではなく **ICMPv6** と **multicast** で行います。この Lab では、neighbor cache をクリアしてから node-a が node-b に ping し、node-a が node-b の **solicited-node multicast** アドレスへ **Neighbor Solicitation**(ICMPv6 type 135)「`2001:db8:23::2` は誰?」を送り、node-b が MAC を載せた **Neighbor Advertisement**(type 136)を返し、node-a の neighbor table に `::2 → MAC` が入る、という解決の様子を観察します。

By the end, you should be able to compare ARP and NDP:

| | ARP (IPv4) | NDP (IPv6) |
|---|---|---|
| Carried by | its own EtherType | ICMPv6 |
| "who has X?" sent to | broadcast (everyone) | solicited-node **multicast** (few) |
| Request / Reply | ARP request / reply | Neighbor Solicitation / Advertisement |
| Cache | ARP table | neighbor cache |

## What You Will Learn

理解したいこと:

- That IPv6 replaces ARP with Neighbor Discovery, built on ICMPv6.
- What a **Neighbor Solicitation** and **Neighbor Advertisement** are.
- What a **solicited-node multicast** address is (`ff02::1:ffXX:XXXX`) and why it is more targeted than broadcast.
- Where the neighbor cache is (`ip -6 neigh`) and what states it has.
- That NDP also does other jobs (router discovery, DAD) — here we focus on address resolution.

This lab does not cover:

- Router Advertisement / SLAAC auto-configuration (needs a router advertising a prefix).
- Duplicate Address Detection (DAD) in depth, or Secure Neighbor Discovery (SEND).
- IPv6 addressing/subnetting beyond what the lab uses.

日本語: IPv6 が ARP を NDP に置き換えること、Neighbor Solicitation/Advertisement、solicited-node multicast アドレス(`ff02::1:ffXX:XXXX`)が broadcast より的を絞れること、neighbor cache(`ip -6 neigh`)とその状態、NDP が router discovery や DAD も担う(ここでは address resolution に集中)ことを学びます。

## RFCで読む場所

| RFC | 章 | 読むポイント |
|---|---|---|
| RFC 4861 | 4.3-4.4 | Neighbor Solicitation / Advertisement のメッセージ形式 |
| RFC 4861 | 7.2 | address resolution の流れ(NS→NA、cache) |
| RFC 4291 | 2.7.1 | solicited-node multicast アドレスの作り方 |
| RFC 4861 | 7.3 | neighbor cache の状態(INCOMPLETE/REACHABLE/STALE) |

## 実験の全体像

IPv6 を付けた2ノードを1本のリンクで繋ぐ。

```text
node-a 2001:db8:23::1/64 ==== eth1/eth1 ==== node-b 2001:db8:23::2/64
```

node-a の neighbor cache をクリアしてから ping すると、NDP の address resolution が走る。

```mermaid
sequenceDiagram
  participant A as node-a (::1)
  participant M as solicited-node multicast<br/>ff02::1:ff00:2
  participant B as node-b (::2)

  Note over A: cache cleared; wants ::2's MAC
  A->>M: Neighbor Solicitation "who has 2001:db8:23::2?"
  Note over B: B listens on ff02::1:ff00:2
  B->>A: Neighbor Advertisement "::2 is at aa:...:cb"
  Note over A: neighbor cache: ::2 -> aa:...:cb (REACHABLE)
```

`2001:db8::/32` は RFC 3849 の IPv6 documentation prefix。

## 必要なもの

推奨環境:

- Linux / WSL2 / Linux VM（IPv6 有効。最近の Linux は標準)
- Docker
- containerlab

使用イメージ:

- `nicolaka/netshoot:latest`（`ip`、`ping6`、`tcpdump`(ICMPv6 デコード) 同梱）

追加イメージは不要。

## 実行手順

```bash
./scripts/labctl.sh run ndp-23
```

### 1. 作業ディレクトリへ移動する

```bash
cd protocol-lab/examples/ndp-23
```

### 2. 起動する

```bash
sudo containerlab deploy -t ndp-23.clab.yml
docker exec clab-ndp-23-node-a ip -6 addr show eth1   # 2001:db8:23::1 と link-local fe80::
```

### 3. neighbor cache をクリアして、解決を観察する

```bash
docker exec clab-ndp-23-node-a ip -6 neigh flush all
docker exec -d clab-ndp-23-node-a tcpdump -i eth1 -n -e "icmp6"
docker exec clab-ndp-23-node-a ping6 -c2 2001:db8:23::2
docker exec clab-ndp-23-node-a pkill -INT tcpdump
docker exec clab-ndp-23-node-a tcpdump -n -e -vv -r /tmp/ndp.pcap
```

見るポイント:

```text
... > 33:33:ff:00:00:02 ... 2001:db8:23::1 > ff02::1:ff00:2: ICMP6, neighbor solicitation, who has 2001:db8:23::2
... 2001:db8:23::2 > 2001:db8:23::1: ICMP6, neighbor advertisement, tgt is 2001:db8:23::2, Flags [solicited, override]
```

### 4. neighbor cache を見る

```bash
docker exec clab-ndp-23-node-a ip -6 neigh show dev eth1
```

```text
2001:db8:23::2 lladdr aa:c1:ab:36:6f:cb REACHABLE
```

`::2` が MAC 付きで cache に入った。以後はこの cache を使い、毎回 solicitation はしない。

## 期待出力

- `ping6 2001:db8:23::2` が成功。
- capture: `neighbor solicitation`(宛先 `ff02::1:ff00:2`)と `neighbor advertisement`(MAC 付き)。
- `ip -6 neigh`: `2001:db8:23::2 lladdr <MAC> REACHABLE`。

## なぜそう動くのか

IP アドレスは「どのホストか」を示すが、同じリンク上で実際にフレームを届けるには **MAC アドレス** が要る。この「IP → MAC」の解決を、IPv4 は ARP、IPv6 は NDP が行う。

- **ICMPv6 の上に載る**: NDP は独立プロトコルではなく **ICMPv6** のメッセージ(type 133-137)。Neighbor Solicitation=135、Neighbor Advertisement=136。だから IPv6 の一部として自然に動く。
- **solicited-node multicast**: ARP は「全員に」broadcast する。NDP はもっと的を絞る。相手のアドレス `2001:db8:23::2` の下位 24bit から **solicited-node multicast** `ff02::1:ff00:2` を作り、そこへ NS を送る。この multicast を listen しているのは、下位 24bit が一致するごく少数のホストだけ。だから無関係なホストを起こさずに済む(broadcast より効率的)。
- **NS → NA**: 相手(node-b)は自分の solicited-node multicast を listen していて、NS を受け取ると、自分の MAC を載せた Neighbor Advertisement を返す。`Flags [solicited, override]` は「要求に応じた/既存 cache を上書きしてよい」の意味。
- **neighbor cache**: 得た「IP → MAC」を cache する(`ip -6 neigh`)。状態は INCOMPLETE(解決中)→ REACHABLE(最近確認済み)→ STALE(しばらく使ってない)などと遷移。以後の通信はこの cache を使い、毎回 solicitation しない。
- **NDP の他の仕事**: address resolution 以外に、router discovery(RS/RA)、prefix/SLAAC、Duplicate Address Detection(DAD、アドレス割当時に自分宛て NS を出して重複確認)も NDP。今回は resolution に集中したが、同じ ICMPv6 の枠組み。

要点は、**「IP → MAC」の解決を、IPv6 は ICMPv6 と的を絞った multicast(solicited-node)で行う**こと。ARP の broadcast より賢い。

## 詰まりやすい点

- **NDP を ARP と全く別物と思う**。役割は同じ(IP→MAC)。手段が ICMPv6+multicast に変わっただけ。
- **broadcast だと思う**。IPv6 に broadcast は無い。solicited-node multicast を使う。
- **solicited-node multicast の作り方**。相手アドレスの下位 24bit を `ff02::1:ff00:0/104` に付ける。
- **link-local を忘れる**。IPv6 は各インターフェースに `fe80::` の link-local も持つ。NDP 自体は link-local でも動く。
- **cache の状態**。REACHABLE/STALE などがある。STALE でも通信は始まり、必要時に再確認する。
- **DAD の NS**。アドレスを付けた瞬間にも NS が出る(重複検出)。ping 由来の NS と混ざって見えることがある。

## 後片付け

```bash
sudo containerlab destroy -t ndp-23.clab.yml --cleanup
```

`labctl.sh run ndp-23` を使った場合は、スクリプトが最後に destroy する。

## 確認問題

1. 同じリンク上で IP パケットを届けるのに、IP アドレスの他に何が要るか。
2. IPv4 の ARP に相当する IPv6 の仕組みは何か。何の上に載るか。
3. Neighbor Solicitation はどのアドレス宛てに送られるか。broadcast との違いは何か。
4. solicited-node multicast アドレスはどう作るか。
5. neighbor cache には何が入るか。どんな状態があるか。
6. NDP は address resolution 以外にどんな仕事をするか(2つ挙げよ)。

## References

- [RFC 4861: Neighbor Discovery for IP version 6 (IPv6)](https://www.rfc-editor.org/rfc/rfc4861)
- [RFC 4291: IP Version 6 Addressing Architecture](https://www.rfc-editor.org/rfc/rfc4291)
- [RFC 4862: IPv6 Stateless Address Autoconfiguration](https://www.rfc-editor.org/rfc/rfc4862)
- [RFC 3849: IPv6 Address Prefix Reserved for Documentation](https://www.rfc-editor.org/rfc/rfc3849)

## 検証済み実行ログ (2026-07-07)

このLabは実機で再現性を確認済みです。

実行環境:

- Ubuntu 26.04 LTS (kernel 7.0.0-27-generic, x86_64)
- Docker 29.1.3
- containerlab 0.77.0
- node-a / node-b: `nicolaka/netshoot:latest`（ping6、tcpdump 同梱）

`PATH="/tmp/pl-shim:$PATH" ./scripts/labctl.sh run ndp-23` で deploy → verify → destroy を実行し、`verification.json` は `"status": "verified"` を返した。

### Neighbor Solicitation → Advertisement(ARP の IPv6 版)

```text
$ docker exec clab-ndp-23-node-a tcpdump -n -e -vv -r ndp.pcap
aa:c1:ab:f1:f4:6f > 33:33:ff:00:00:02 ... 2001:db8:23::1 > ff02::1:ff00:2:
    ICMP6, neighbor solicitation, who has 2001:db8:23::2
aa:c1:ab:36:6f:cb > aa:c1:ab:f1:f4:6f ... 2001:db8:23::2 > 2001:db8:23::1:
    ICMP6, neighbor advertisement, tgt is 2001:db8:23::2, Flags [solicited, override]
```

node-a は node-b の **solicited-node multicast**（`ff02::1:ff00:2`、L2 では `33:33:ff:00:00:02`）へ NS を送り、node-b が MAC を載せた NA を返している。broadcast ではなく、下位 24bit が一致するホストだけに届く multicast を使うのが ARP との違い。

### 解決後の neighbor cache

```text
$ docker exec clab-ndp-23-node-a ip -6 neigh show dev eth1
2001:db8:23::2 lladdr aa:c1:ab:36:6f:cb REACHABLE
```

`2001:db8:23::2` が MAC 付きで cache に入り、状態は `REACHABLE`。以後の通信はこの cache を使い、毎回 solicitation はしない。IPv6 は「IP → MAC」の解決を、ICMPv6 と的を絞った multicast で行う——ARP の後継。

### Cleanup

```bash
containerlab destroy -t ndp-23.clab.yml --cleanup
```
