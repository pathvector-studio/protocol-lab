# Bridge Learning Reading Guide for Lab 44

This guide points at the material that matters for Lab 44. A Linux bridge implements the MAC bridge described by IEEE 802.1D, so the standard supplies the model and the Linux manual pages supply the controls.

日本語: この guide は Lab 44 の読みどころを整理したものです。Linux bridge は IEEE 802.1D の MAC bridge を実装したものなので、考え方は規格から、操作は Linux の man page から読みます。

Target material:

- IEEE 802.1D — MAC bridges: the learning process, the filtering database, and ageing
- [bridge(8) manual page](https://man7.org/linux/man-pages/man8/bridge.8.html) — `bridge fdb show/add/del`
- [ip-link(8) manual page](https://man7.org/linux/man-pages/man8/ip-link.8.html) — bridge device options, `ageing_time`
- [Linux bridge kernel documentation](https://www.kernel.org/doc/html/latest/networking/bridge.html)

## Reading Goal

For this lab, read a switch as *a table plus three rules*. The table maps a MAC address to a port. The rules are: learn the **source** address of every frame you receive; forward to the one port if the **destination** is in the table; flood to every other port if it is not. Ageing is the fourth idea — entries must expire, or the table would be a permanent and eventually wrong record.

日本語: このLabでは、switch を「表 + 3つの規則」として読みます。表は MAC アドレスとポートの対応。規則は、受け取ったフレームの **送信元** を学習する / **宛先** が表にあればそのポートだけへ転送する / 無ければ他の全ポートへ flood する。4つ目の考えが ageing で、エントリは期限切れで消えなければなりません。消えないと表は「永久で、いずれ間違っている」記録になります。

Start with these ideas:

- **Learning is from the source, forwarding is by the destination.** These are different fields of the same frame. A bridge never learns from a destination address — it has no evidence that the destination is where it thinks.
- **Flooding is the safe default, not a failure.** An unknown destination could be anywhere, so the bridge sends it everywhere except back out the ingress port. Delivery still works; it just costs bandwidth on every other port.
- **One frame in the other direction is enough.** The bridge learns where B is from B's *reply*, not from A's request. That is why the flooding usually stops after a single round trip.
- **Broadcast is always flooded.** ARP requests, DHCP discovers and the like go to every port regardless of what the table holds. Learning does not and cannot suppress them.
- **Ageing is what makes a moved host reachable again.** Default on Linux is 300 seconds. Note the unit trap: `ip link set ... type bridge ageing_time N` takes **centiseconds**, so `500` means 5 seconds.

日本語の要点:

- 学習は **送信元** から、転送は **宛先** で。同じフレームの別のフィールドを見ている。宛先からは学習しない(宛先が本当にそこにいる証拠はないため)。
- flood は失敗ではなく安全側の既定動作。宛先不明なら入ってきたポート以外の全部へ出す。届くことは届く。他ポートの帯域を使うだけ。
- 逆向きの1フレームで学習が済む。bridge が B の位置を知るのは A の request ではなく B の **応答** から。だから往復1回で flood が止まる。
- broadcast は常に flood される。ARP request や DHCP discover は表の中身に関係なく全ポートへ。学習では抑制できない。
- ageing があるからホストがポートを移動しても再び到達できる。Linux の既定は 300 秒。単位の罠があり、`ip link set ... type bridge ageing_time N` は **センチ秒**。`500` は 5 秒。

## What To Skip

STP/RSTP (this lab has no loops), VLAN filtering on the bridge (`vlan_filtering`, covered by Lab 26 at the tagging level), multicast snooping (Lab 29 covers IGMP), and the `bridge` netfilter hooks.

日本語: STP/RSTP(このLabにループはない)、bridge の VLAN filtering(タグの話は Lab 26)、multicast snooping(IGMP は Lab 29)、bridge の netfilter フックは範囲外です。

## Questions To Hold While Reading

- Which field does the bridge learn from, and which field does it forward by?
- After A sends one frame to B, what exactly does the bridge know — and what does it still not know?
- Why does the bystander need promiscuous mode to observe flooding?
- What breaks if entries never age out?

日本語:

- bridge はどのフィールドから学習し、どのフィールドで転送するか。
- A が B へ1フレーム送った直後、bridge は何を知っていて、何をまだ知らないか。
- 傍観者が flooding を観測するのに promiscuous mode が要るのはなぜか。
- エントリが永久に消えないと何が壊れるか。
