# VXLAN Overlay Reading Guide for Lab 18

This guide helps you read the RFC sections that matter for Lab 18. It is meant to be used alongside the RFC, not instead of it.

日本語: この guide は、Lab 18 に必要な RFC の読みどころを整理したものです。RFC本文の代わりではなく、RFC本文と一緒に使うための案内です。

Target RFC:

- [RFC 7348: VXLAN](https://www.rfc-editor.org/rfc/rfc7348)

## Reading Goal

For this lab, read VXLAN as *encapsulation without encryption*: an L2 frame wrapped in UDP and carried across an L3 underlay. The contrast with WireGuard (Lab 16) is the point — same "wrap in UDP" shape, but VXLAN does not hide the payload.

日本語: このLabでは、VXLAN を「暗号化なしの encapsulation」として読みます。L2 フレームを UDP に包んで L3 の underlay で運ぶ。Lab 16(WireGuard)との対比が要点で、「UDP に包む」形は同じでも、VXLAN は中身を隠しません。

Start with these ideas:

- VXLAN carries Ethernet frames (Layer 2) inside UDP (Layer 4), across an IP underlay (Layer 3).
- A 24-bit VNI identifies the overlay; VXLAN uses UDP port 4789.
- Encapsulation and encryption are different jobs — VXLAN does the first, not the second.

## Lab #18 で読む場所

| 優先 | RFC | 章 | 読む目的 |
|---|---|---|---|
| 1 | RFC 7348 | 4 | フレームフォーマット: outer Ethernet/IP/UDP + VXLAN header + inner Ethernet |
| 2 | RFC 7348 | 3 | VNI(24bit)、UDP 4789、overlay の分離 |
| 3 | RFC 7348 | 5 | VTEP(encapsulate/decapsulate する端点) |

## VXLAN のフレーム

RFC 7348 4。外側から内側へ:

```text
[ outer Ethernet ][ outer IP ][ outer UDP (dst 4789) ][ VXLAN header (VNI) ][ inner Ethernet ][ inner IP ][ ... ]
```

- **outer**: underlay を流れる普通の IP/UDP パケット。宛先 UDP ポートは 4789。
- **VXLAN header**: 24bit の **VNI** を含む。どの overlay(仮想 L2)かを示す。
- **inner**: 元の Ethernet フレーム(その中に IP など)。VXLAN はこれをそのまま運ぶ。

内側が Ethernet フレームまるごと、というのが「L2 overlay」たるゆえん。

## VNI と分離

RFC 7348 3。

- VNI は 24bit = 約 1600 万個。VLAN の 12bit(4094 個)を大きく超える(VXLAN の "eXtensible")。
- 同じ underlay 上に、VNI ごとに独立した overlay をいくつも重ねられる。
- 両端の VTEP が同じ VNI を使わないと通らない(このLabは VNI 100)。

## VTEP

RFC 7348 5。

- **VTEP**(VXLAN Tunnel EndPoint): encapsulate/decapsulate を行う端点。物理ホストや仮想スイッチ、このLabでは各ノードの `vxlan0`。
- 送信 VTEP は「宛先 MAC → 相手 VTEP の underlay アドレス」を知る必要がある。本番は multicast や EVPN の control plane で学習するが、このLabは `remote <peer>` で静的に指定した point-to-point。

## encapsulation ≠ encryption

- VXLAN の仕事は「包んで運ぶ」だけ。**暗号化はしない**。
- だから underlay を capture すると、VXLAN ヘッダも内側フレームも平文で見える(tcpdump がデコードする)。
- 秘匿が要るなら、信頼できる underlay で使うか、underlay を IPsec 等で別途暗号化する。
- Lab 16 の WireGuard は encapsulation **と** encryption の両方を行う。ここが決定的な違い。

## Message から読む

Lab の capture を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `10.0.0.1.x > 10.0.0.2.4789: VXLAN, vni 100` | outer UDP + VXLAN header(underlay) |
| その直後の `10.200.0.1 > 10.200.0.2: ICMP echo` | inner packet(平文で見える) |
| `ip -d link show vxlan0` の `vxlan id 100 ... dstport 4789` | VTEP の設定 |

## よくある誤解

- overlay = 秘匿、ではない。VXLAN は暗号化しない。
- overlay と underlay のアドレスは別物。ping は overlay 側。
- VNI を両端で揃えないと通らない。
- VXLAN は L2(Ethernet)を運ぶ。L3 だけの tunnel(GRE, WireGuard)とは層が違う。
- VXLAN ヘッダのぶん overlay の MTU は小さくなる。

## 前後の Lab とのつながり

- Lab 16(WireGuard)= UDP encapsulation + 暗号化(L3)。Lab 18(VXLAN)= UDP encapsulation のみ(L2)。並べると「包む/暗号化する」の直交が見える。
- VXLAN は DC の network virtualization の基盤(EVPN と組み合わせて大規模に使う)。
- 「overlay を暗号化したい」需要が、IPsec や WireGuard を underlay に敷く構成につながる。
