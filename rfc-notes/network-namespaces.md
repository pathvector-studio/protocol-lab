# Network Namespaces Reading Guide for Lab 43

This guide points at the material that matters for Lab 43. Network namespaces, veth pairs and the Linux bridge are kernel mechanisms rather than a protocol, so the primary references are the Linux manual pages, with IEEE 802.1D for what a bridge is supposed to do.

日本語: この guide は Lab 43 の読みどころを整理したものです。network namespace・veth・Linux bridge はプロトコルではなくカーネルの仕組みなので、主に Linux の man page を読み、bridge の振る舞いの背景として IEEE 802.1D を挙げます。

Target material:

- [network_namespaces(7) manual page](https://man7.org/linux/man-pages/man7/network_namespaces.7.html)
- [ip-netns(8) manual page](https://man7.org/linux/man-pages/man8/ip-netns.8.html)
- [veth(4) manual page](https://man7.org/linux/man-pages/man4/veth.4.html)
- [ip-link(8) manual page](https://man7.org/linux/man-pages/man8/ip-link.8.html)
- IEEE 802.1D — MAC bridges (learning and flooding; the FDB that Lab 44 takes apart)

## Reading Goal

For this lab, read a namespace as *a complete, private copy of the network stack*, and a veth pair as *a cable with two ends that can live in different namespaces*. A bridge is then just the switch you plug those cables into. A container is not a special kind of thing — it is a process whose network namespace happens to be wired this way.

日本語: このLabでは、namespace を「ネットワークスタックまるごとの private なコピー」、veth を「両端が別々の namespace に置ける1本のケーブル」として読みます。bridge はそのケーブルを挿す switch にすぎません。コンテナは特別な何かではなく、「network namespace がこう配線されたプロセス」です。

Start with these ideas:

- **A namespace owns its own everything.** Interfaces, routing table, ARP/neighbour cache, netfilter rules, socket port space. Two namespaces can both have an interface called `eth0` and both have a `127.0.0.1`, and none of it collides — names and addresses only have to be unique *within* a namespace.
- **A veth pair is inseparable.** `ip link add A type veth peer name B` creates two interfaces bonded back to back. A frame written into `A` comes out of `B`, always. Moving `B` into a namespace does not break the pairing; it is what makes the pair useful.
- **Configuration is not connectivity.** Both ends can be up, addressed and on the same subnet, and still nothing passes — because the host-side ends are not attached to anything. This is the moment Lab 43 is built around.
- **A bridge learns.** When you enslave the host-side ends to a bridge, it starts recording which port each *source* MAC arrived on, in its forwarding database (FDB). Traffic to an unknown destination is flooded to every port; once the address is learned, it is forwarded to one port.
- **`ip netns exec` is just "run this in that namespace."** It is not a container runtime, a sandbox or a security boundary by itself. It only changes which network stack the process sees.

日本語の要点:

- namespace はインターフェース・ルーティングテーブル・ARP キャッシュ・netfilter・ポート空間を丸ごと自前で持つ。名前やアドレスは namespace 内で一意ならよい。
- veth は2つで1組。片方に入ったフレームは必ずもう片方から出る。片端を namespace に移しても対は切れない。
- 「設定した」と「つながった」は別。両端が up でも、host 側の端がどこにも挿さっていなければ通らない。
- bridge は送信元 MAC を見て「どのポートの先にいるか」を FDB に学習する。宛先未知は flood、学習後は該当ポートへ転送。
- `ip netns exec` は「そのnamespaceで実行する」だけ。それ自体はコンテナでも隔離境界でもない。

## What To Skip

You do not need namespace *lifecycle* details (how the kernel refcounts a namespace, `setns(2)`, `unshare(2)` flags), nor the other namespace types (PID, mount, user). Bridge STP is out of scope here — the lab builds a single bridge with no loops.

日本語: namespace のライフサイクル(カーネル内の参照カウント、`setns(2)`、`unshare(2)` のフラグ)や、他の namespace 種別(PID/mount/user)は不要です。bridge の STP もこのLabの範囲外(ループのない bridge 1つだけ)。

## Questions To Hold While Reading

- Why can two namespaces both have an interface named `eth0`?
- If both namespaces are configured correctly on one subnet, what exactly is missing before the bridge exists?
- What does the bridge learn, and from which field of the frame?
- What does `docker run` do that this lab does not?

日本語:

- なぜ2つの namespace が同じ `eth0` という名前を持てるのか。
- 同じサブネットに正しく設定されているのに、bridge が無いと何が足りないのか。
- bridge はフレームのどのフィールドから何を学習するのか。
- `docker run` がやっていて、このLabがやっていないことは何か。
