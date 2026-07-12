# Learning Paths

Protocol Lab has 42 labs. Labs 01–12 are a designed sequence; the rest were added in
themed batches. This page groups all 42 by genre and gives goal-based routes, so you
can navigate by interest instead of lab number. When a protocol hooks you, the sibling
intermediate course [Protocol in Code](https://github.com/pathvector-studio/protocol-in-code)
reads the same protocol as small Python programs — its
[LEARNING_PATHS.md](https://github.com/pathvector-studio/protocol-in-code/blob/main/LEARNING_PATHS.md)
has the lab-by-lab cross-reference.

日本語: Protocol Lab は42本。Lab 01〜12 は設計された導入シーケンスで、残りはテーマ別
バッチで増えました。このページは42本をジャンルで束ね、目的別ルートを示します。
気に入ったプロトコルは中級編 Protocol in Code で「コードとして」読めます。

## Genres

| Genre | Labs |
|---|---|
| Routing 経路制御 | 01–03 (BGP), 04 (RPKI), 34 (OSPF), 35 (BFD), 31 (anycast), 32 (ECMP), 38 (PBR), 39 (RPF) |
| Names & trust 名前と信頼 | 05–06 (DNS), 13 (DNSSEC), 14 (DoT/DoH), 17 (DANE), 42 (split-horizon) |
| Transport トランスポート | 07–08 (TCP), 30 (congestion), 25 (PMTUD), 37 (MSS), 28 (QoS) |
| The web path Webの配管 | 09 (TLS), 15 (mTLS), 10 (HTTP), 27 (redirects/cookies), 11 (QUIC), 12 (end-to-end), 33 (IPVS), 41 (DNS RR) |
| The local segment ローカルセグメント | 22 (DHCP), 23 (NDP), 24 (ARP), 26 (VLAN), 29 (IGMP) |
| Tunnels & overlays トンネル | 16 (WireGuard), 18 (VXLAN), 21 (GRE) |
| Edge & boundary エッジと境界 | 19 (traceroute), 20 (NAT), 40 (DNAT), 36 (firewall) |

## Routes

### First contact 最初の12本（そのまま）

Labs 01–12 in order. This is the designed on-ramp: BGP → RPKI → DNS → TCP → TLS →
HTTP → QUIC → one request end-to-end. Two labs a weekend finishes it in six weeks.

日本語: 迷ったら Lab 01〜12 を順番に。週末2本ペースで6週間の設計です。

### "My home network, explained" 自宅ネットワーク解明ルート

22 (DHCP) → 24 (ARP) → 20 (NAT) → 40 (port forward) → 19 (traceroute) → 05–06 (DNS)
→ 36 (firewall) → 16 (WireGuard). Everything between your laptop and the internet.

### Web engineer's packet literacy Webエンジニアのパケット教養

05–06 (DNS) → 07–08 (TCP) → 09 (TLS) → 10, 27 (HTTP) → 11 (QUIC) → 12 (end-to-end)
→ 33, 41 (load balancing). Then continue in Protocol in Code's web-engineer route.

### Datacenter & operations データセンター・運用ルート

34 (OSPF) → 35 (BFD) → 26 (VLAN) → 18 (VXLAN) → 32 (ECMP) → 33 (IPVS) → 28 (QoS)
→ 31 (anycast) → 36 (firewall) → 39 (RPF).

### After the labs そのあと

The batch-4 platform labs (43–46: Kubernetes, service mesh, VPC, eBPF — in planning)
extend "read the wire" to "read the platform". For depth on any protocol you already
ran, switch to Protocol in Code — the beginner→intermediate hand-off table lives in
its LEARNING_PATHS.md.
