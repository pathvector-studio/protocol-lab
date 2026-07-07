# WireGuard Reading Guide for Lab 16

This guide points at the material that matters for Lab 16. WireGuard is not defined by a single RFC; it is a whitepaper plus a small, fixed set of modern cryptographic primitives (each with its own RFC).

日本語: この guide は Lab 16 の読みどころを整理したものです。WireGuard は単一の RFC ではなく、論文と、少数の現代的な暗号プリミティブ(それぞれ RFC あり)で定義されます。

Target material:

- [WireGuard whitepaper (Donenfeld)](https://www.wireguard.com/papers/wireguard.pdf)
- [RFC 7748: Elliptic Curves for Security (X25519)](https://www.rfc-editor.org/rfc/rfc7748)
- [RFC 8439: ChaCha20-Poly1305](https://www.rfc-editor.org/rfc/rfc8439)

## Reading Goal

For this lab, read a tunnel as *encapsulation with encryption*: an inner IP packet is wrapped inside an outer UDP packet, encrypted end to end between two peers. WireGuard is the smallest clean example.

日本語: このLabでは、tunnel を「暗号化つきの encapsulation」として読みます。内側の IP パケットを外側の UDP パケットに包み、2つの peer 間で暗号化する。WireGuard はその最小できれいな例。

Start with these ideas:

- A tunnel has an underlay (the real network) and an overlay (the addresses inside the tunnel).
- WireGuard identifies each peer by a public key, and pins it to an endpoint and a set of allowed IPs.
- The outer packet is UDP; the inner packet (any protocol) is encrypted inside it.

## Lab #16 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | whitepaper §1-2 | 設計目標、peer = 公開鍵、endpoint、allowed-ips |
| 2 | whitepaper §5 | cryptokey routing(allowed-ips が認証とルーティングを兼ねる) |
| 3 | whitepaper §5.4 | UDP での運搬、handshake の位置づけ |
| 4 | RFC 7748 | X25519(peer 間の鍵合意) |
| 5 | RFC 8439 | ChaCha20-Poly1305(パケットの暗号化+認証) |

## underlay と overlay

トンネルの一番大事な区別。

| | underlay | overlay(tunnel) |
|---|---|---|
| 何 | 実際のネットワーク | トンネル内の仮想ネットワーク |
| Lab のアドレス | `10.0.0.0/24`(eth1) | `10.99.0.0/24`(wg0) |
| capture で見えるもの | UDP/51820 の暗号文 | 復号後の平文(ICMP など) |

- overlay のパケットは、underlay のパケットの**中身**として運ばれる。
- だから underlay を覗いても、見えるのは「暗号化された UDP」だけ。中の宛先やプロトコルは分からない。

## peer = 公開鍵(cryptokey routing)

whitepaper §2, §5。

- WireGuard に user/password は無い。各 peer は **公開鍵**で識別される。
- 各 peer に対して **allowed-ips** を設定する。これは「この peer が名乗ってよい overlay アドレス」。
  - 送信時: overlay 宛先がどの peer の allowed-ips に入るかで、暗号化して送る相手を決める(routing)。
  - 受信時: 復号したパケットの送信元が、その peer の allowed-ips に入っていなければ捨てる(authentication)。
- この1つの仕組みが**ルーティングと認証を兼ねる**のが WireGuard の要。

## UDP での encapsulation

whitepaper §5.4。

- 暗号化したパケットを、相手の **endpoint**(IP:51820)へ **UDP** で送る。
- TCP を使わないのは、トンネルの中でまた TCP が走ることが多く(TCP over TCP は悪相性)、また UDP のほうが NAT/ロードバランサを越えやすいから。
- Lab の underlay capture に見えるのは、まさにこの UDP/51820。

## 暗号(RFC 7748 / 8439)

- **X25519(RFC 7748)**: peer 間で共有鍵を作る鍵合意。公開鍵はこの曲線上の点。
- **ChaCha20-Poly1305(RFC 8439)**: 各パケットを暗号化し、改ざん検出タグ(Poly1305)を付ける AEAD。
- handshake は Noise Protocol Framework をベースにしている(参考)。細部はこのLabの範囲外だが、「現代的な固定の暗号だけを使い、選択肢を減らして安全にする」のが WireGuard の思想。

## 他の暗号化 Lab との違い

| Lab | 包む対象 | 層 |
|---|---|---|
| 09 TLS | 1本の TCP ストリーム | transport の上 |
| 14 DoT/DoH | DNS メッセージ | application |
| 16 WireGuard | **任意の IP パケット** | network(その下の UDP に乗せる) |

- TLS/DoT/DoH は「特定のプロトコル」を暗号化する。
- WireGuard は「IP パケットそのもの」を暗号化するので、上で TCP でも UDP でも ICMP でも、まとめて包める。VPN が「全部通す」のはこのため。

## Message から読む

Lab の capture を用語に対応づける。

| 見えるもの | 意味 |
|---|---|
| `10.0.0.1.51820 > 10.0.0.2.51820: UDP` | underlay の暗号文(encapsulated) |
| underlay に ICMP が出ない | 中身は暗号化されている |
| `wg0` に `ICMP echo request` | 端点で復号された平文 |
| `wg show` の `latest handshake` | peer 間の鍵合意が成立した |

## よくある誤解

- `wg0` で平文が見える = 暗号化されていない、ではない。wg0 は復号の出入口。
- underlay と overlay のアドレスは別物。ping するのは overlay。
- 公開鍵を配り、秘密鍵は手元に。allowed-ips が認証を兼ねる。
- WireGuard は UDP。TCP ではない。
- データ経路はホストカーネル(userspace は設定だけ)。

## 前後の Lab とのつながり

- Lab 09(TLS)、Lab 14(DoT/DoH)で「特定のものを暗号化」を見た。Lab 16 は「IP パケットごと暗号化」。
- 同じ「暗号化 + 認証」を、対象と層を変えて適用しているのが一望できる。
- この先、IPsec、ゼロトラストネットワーク、mesh VPN などへ広がる。
