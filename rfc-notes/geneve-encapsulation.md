# GENEVE Reading Guide for Lab 45

This guide points at the material that matters for Lab 45. GENEVE has a proper RFC, and the lab is a direct comparison against VXLAN, so read both specifications' header sections next to each other.

日本語: この guide は Lab 45 の読みどころを整理したものです。GENEVE には RFC があり、この Lab は VXLAN との直接比較なので、両方のヘッダの節を並べて読みます。

Target material:

- [RFC 8926: Geneve — Generic Network Virtualization Encapsulation](https://www.rfc-editor.org/rfc/rfc8926) — §3 (header), §3.5 (options)
- [RFC 7348: VXLAN](https://www.rfc-editor.org/rfc/rfc7348) — §5 (header), for the contrast
- [ip-link(8) manual page](https://man7.org/linux/man-pages/man8/ip-link.8.html) — `type geneve`, `type vxlan`
- [RFC 1918](https://www.rfc-editor.org/rfc/rfc1918) — the lab's private addresses

## Reading Goal

For this lab, read GENEVE as *VXLAN plus two admissions*: that a tunnel should say what it is carrying, and that whatever fields you pick today will be wrong in five years. Those two admissions become the **Protocol Type** field and the **variable-length option (TLV) area**. Everything else — outer UDP, a 24-bit VNI, an inner frame in the clear — is the same shape as VXLAN.

日本語: このLabでは、GENEVE を「VXLAN + 2つの認め」として読みます。1つは「トンネルは自分が何を運んでいるか言うべきだ」、もう1つは「今日決めたフィールドは5年後には足りない」。この2つがそれぞれ **Protocol Type** フィールドと **可変長オプション(TLV)領域** になっています。それ以外——外側 UDP、24bit の VNI、平文の内側フレーム——は VXLAN と同じ形です。

Start with these ideas:

- **Both headers are 8 bytes at minimum.** VXLAN spends 4 of them on reserved zeroes. GENEVE spends the same space on `Ver`/`Opt Len` and a 16-bit `Protocol Type`.
- **VXLAN carries Ethernet, implicitly and only.** There is no field that says so. GENEVE writes `0x6558` (Transparent Ethernet Bridging) and could write something else.
- **`Opt Len` is the whole point.** It counts 4-byte words of TLV options between the header and the payload. New capabilities become new option classes, not a new protocol on a new UDP port.
- **Encapsulation is not encryption.** The inner frame is readable on the underlay in both. This is the same conclusion as Lab 18 (VXLAN) and Lab 21 (GRE); GENEVE does not change it.
- **The outer source port is deliberately random-looking.** The encapsulator hashes the inner flow into it so that ECMP (Lab 32) can spread tunnelled flows across paths without parsing the payload.
- **MTU is the operational trap.** Encapsulation costs roughly 50 bytes. Whether the tunnel device tells you that depends on how it was created — see what the lab observes.

日本語の要点:

- どちらもヘッダは最小8バイト。VXLAN はうち4バイトを予約のゼロに使う。GENEVE は同じ場所を `Ver`/`Opt Len` と16bitの `Protocol Type` に使う。
- VXLAN は Ethernet を「暗黙に、それだけ」運ぶ。そう書いてあるフィールドが無い。GENEVE は `0x6558` と明示するので、別のものも運べる。
- **`Opt Len` が本題**。ヘッダとペイロードの間に入る TLV オプションを4バイト単位で数える。新機能は「新しいオプションクラス」であって「新しい UDP ポートの新プロトコル」ではない。
- カプセル化は暗号化ではない。内側フレームは underlay で読める。Lab 18(VXLAN)・Lab 21(GRE)と同じ結論で、GENEVE でも変わらない。
- 外側の source port はわざとバラバラに見える。内側フローのハッシュを入れることで、ECMP(Lab 32)が中身を解析せずにトンネルを分散できる。
- MTU が運用上の罠。カプセル化に約50バイトかかる。それをデバイスが申告するかは作り方次第——Lab の観察を参照。

## What To Skip

The `O` (OAM) and `C` (critical) bits, IPv6 underlays, multicast VNI learning, and the security considerations sections. Also skip the control planes (EVPN, OVN/NSX) — this lab is static point-to-point, with no control plane at all.

日本語: `O`(OAM)/`C`(critical) ビット、IPv6 underlay、multicast による VNI 学習、security considerations は範囲外。コントロールプレーン(EVPN、OVN/NSX)も扱いません(この Lab は制御なしの静的な point-to-point)。

## Questions To Hold While Reading

- Which two GENEVE header fields have no counterpart in VXLAN, and what does each buy you?
- If both put a 24-bit VNI in the same place, why was a new protocol needed at all?
- Why does the outer UDP source port change per inner flow?
- Encapsulation costs ~50 bytes — where does that show up, and where does it fail to show up?

日本語:

- VXLAN に対応物が無い GENEVE のフィールドは何と何か。それぞれ何が得られるか。
- 同じ位置に24bitの VNI を置くなら、なぜ新しいプロトコルが必要だったのか。
- 外側 UDP の source port が内側フローごとに変わるのはなぜか。
- カプセル化の約50バイトは、どこに現れ、どこには現れないか。
