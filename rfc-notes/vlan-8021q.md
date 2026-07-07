# 802.1Q VLAN Reading Guide for Lab 26

This guide helps you read the material that matters for Lab 26. VLANs are defined by IEEE 802.1Q, not an IETF RFC, so the primary reference is the IEEE standard plus a few related RFCs.

日本語: この guide は、Lab 26 の読みどころを整理したものです。VLAN は IETF の RFC ではなく IEEE 802.1Q で定義されるので、主に IEEE 標準と関連 RFC を挙げます。

Target material:

- [IEEE 802.1Q (VLANs)](https://standards.ieee.org/standard/802_1Q-2018.html)
- [RFC 5517: Private VLANs](https://www.rfc-editor.org/rfc/rfc5517)

## Reading Goal

For this lab, read a VLAN as *a tag that turns one physical LAN into several isolated virtual ones*. The tag carries a VLAN ID; devices only see frames for their VLAN.

日本語: このLabでは、VLAN を「1つの物理 LAN を複数の分離した仮想 LAN に変える tag」として読みます。tag が VLAN ID を運び、機器は自分の VLAN のフレームだけを見る。

Start with these ideas:

- An 802.1Q tag (4 bytes) inserts a VLAN ID into the Ethernet frame.
- A trunk link carries tagged frames for multiple VLANs; each side sorts by tag.
- Different VLANs are different broadcast domains — isolated on the same wire.

## Lab #26 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | IEEE 802.1Q | VLAN tag の形式(TPID 0x8100、PCP 3bit、DEI 1bit、VID 12bit) |
| 2 | IEEE 802.1Q | trunk / access、tag の付与と除去 |
| 3 | RFC 826 | ARP は VLAN 内で閉じる(各 VLAN が別 broadcast domain) |
| 4 | RFC 5517 | Private VLAN(分離をさらに細分する発展) |

## 802.1Q tag

- Ethernet フレームの送信元 MAC の直後に、**4バイトの tag** を挿入する。
- 内訳:
  - **TPID** 0x8100(このフレームは 802.1Q tagged だと示す EtherType)。
  - **PCP** 3bit(優先度、QoS 用)。
  - **DEI** 1bit(廃棄可否)。
  - **VID** 12bit(**VLAN ID**、1〜4094)。
- tag は IP より下(L2)。capture では `ethertype 802.1Q (0x8100) ... vlan <id>` と見える。

## trunk と access

- **trunk**: 複数 VLAN の tagged frame を1本のリンクで運ぶ。受け手は VID を見て対応する VLAN に振り分ける。このLabの eth1 が trunk 相当。
- **access**: 1つの VLAN に属し、フレームは tag 無し(untagged)。スイッチが access port で tag を付け外しする。
- Lab では両端が subinterface(`eth1.100` / `eth1.200`)を持つので、trunk を直結した形。

## broadcast domain の分離

- VLAN 100 のフレームは VLAN 100 の口だけに届く。VLAN 200 には届かない。
- つまり VLAN ごとに **独立した broadcast domain**。ARP(Lab 24)の broadcast も VLAN 内で閉じる。
- VLAN 間で通信するには、L3 のルータ(**inter-VLAN routing**、router-on-a-stick など)が要る。VLAN だけでは L2 で分離されたまま。

## VLAN と VXLAN

| | VLAN (802.1Q) | VXLAN (Lab 18) |
|---|---|---|
| 範囲 | 1本のリンク / ローカル L2 | L3 網を越える |
| ID | VID 12bit(4094) | VNI 24bit(約1600万) |
| カプセル化 | tag を挿入 | UDP に encapsulation |
| 用途 | 構内の LAN 分割 | DC の大規模仮想化 |

- VLAN の 4094 個では足りず、L3 越えも要る、という DC の要求が VXLAN を生んだ。

## Message から読む

Lab の capture を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `ethertype 802.1Q (0x8100)` | tagged frame |
| `vlan 100` / `vlan 200` | VID(どの VLAN か) |
| VLAN 100 の capture に vlan 200 が無い | broadcast domain の分離 |
| `eth1.100` / `eth1.200` | VLAN subinterface(trunk の振り分け先) |

## よくある誤解

- VLAN 間が自動で通ると思う。別 broadcast domain。L3 routing が要る。
- tag は IP に入ると思う。L2(Ethernet ヘッダ内)。
- VID は無限と思う。12bit = 4094。足りなければ VXLAN。
- trunk と access を混同する。trunk は tagged 複数 VLAN、access は untagged 単一。
- IP サブネットと VLAN は同じと思う。別概念(普通は揃えるが)。

## 前後の Lab とのつながり

- Lab 24(ARP)/ Lab 23(NDP)の broadcast/multicast は VLAN 内で閉じる。
- Lab 18(VXLAN)は VLAN の限界(スケール・L3 越え)を超えるための発展。
- QoS の PCP フィールドは、tc(帯域制御)などの優先度制御につながる。
