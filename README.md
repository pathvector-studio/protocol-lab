# Protocol Lab

Protocol Lab is a free learning project for network protocols. Each lab starts from a small part of an RFC, turns it into a runnable experiment, and uses command output or packet captures to explain what happened.

日本語: Protocol Lab は、RFCを読み、手を動かし、パケットやログを見ながらネットワークプロトコルを学ぶための無料教材です。小さな実験を通して、読んだ仕様と観察できる挙動を結びつけます。

## Start Here

The first track is BGP/RPKI. Start with:

- [BGP Lab 01: One Prefix Announcement You Can Explain](labs/bgp-01-as-prefix-announcement.md)
- [RFC 4271 Reading Guide for BGP Lab 01](rfc-notes/bgp-rfc4271.md)
- [BGP Lab 02: Watch a Route Appear, Disappear, and Come Back](labs/bgp-02-update-nexthop-withdrawal.md)
- [RFC 4271 Reading Guide for BGP Lab 02](rfc-notes/bgp-rfc4271-lab02.md)
- [BGP Lab 03: Competing Origins and the First Route-Leak Question](labs/bgp-03-competing-origins-route-leaks.md)
- [RFC 4271 Reading Guide for BGP Lab 03](rfc-notes/bgp-rfc4271-lab03.md)
- [RPKI Lab 04: ROAs and Origin Validation](labs/rpki-04-roa-origin-validation.md)
- [RPKI Origin Validation Reading Guide for Lab 04](rfc-notes/rpki-origin-validation.md)
- [Full 12-lab learning roadmap](ROADMAP.md)

Lab 01 builds a two-router eBGP topology, advertises one documentation prefix, and helps you explain the resulting route in terms of NLRI, AS_PATH, NEXT_HOP, and ORIGIN.

最初のトラックは BGP/RPKI です。Lab 01 では、2台の仮想ルータで eBGP を動かし、1つの documentation prefix を広告します。Lab 02 では、その route が現れ、withdraw で消え、再広告で戻るところを観察します。Lab 03 では、同じ prefix が複数の origin AS から見える状態を作ります。Lab 04 では、ROA/VRP と origin validation の3状態を観察します。全体像は [12-lab learning roadmap](ROADMAP.md) を見てください。

## What You Will Do

- Read the RFC sections that matter for one small concept.
- Run a minimal local experiment.
- Inspect routing tables, logs, and packet captures.
- Connect the observed output back to protocol terms.
- Answer short review questions before moving to the next lab.

日本語:

- 1つの概念に必要なRFCの章を読む。
- 小さなローカル実験を動かす。
- routing table、ログ、pcapを観察する。
- 観察結果をプロトコル用語に対応づける。
- 確認問題で理解を固めてから次へ進む。

## Requirements

Most hands-on labs assume a Linux environment with:

- Docker
- containerlab
- tcpdump
- Wireshark or tshark

macOS users should run the labs inside a Linux VM, WSL-style environment, or another Linux host where containerlab can create network namespaces.

日本語: ハンズオンは Linux 環境を前提にしています。macOS の場合は、Linux VM や Linux ホスト上で実行してください。containerlab が network namespace を作れる環境が必要です。

## Safety

Labs use documentation address space such as `203.0.113.0/24` and private ASNs such as `65001`. These examples are for closed local labs only. Do not announce them to the public Internet.

日本語: Labでは `203.0.113.0/24` のような documentation address と `65001` のような private ASN を使います。これは閉じたローカル実験用です。実インターネットへ広告しないでください。

## Repository Guide

| Path | What it contains |
|---|---|
| `labs/` | Hands-on labs with commands, expected observations, explanations, and review questions |
| `rfc-notes/` | Reading guides that map RFC sections to each lab |
| `examples/` | Minimal containerlab, FRRouting, and script examples used by the labs |
| `scripts/` | Small helper scripts for running labs in a Linux environment |
| `assets/` | Optional diagrams, screenshots, and small packet captures referenced by lessons |

日本語:

| パス | 内容 |
|---|---|
| `labs/` | コマンド、期待される観察結果、解説、確認問題を含むハンズオン |
| `rfc-notes/` | Labと対応するRFC reading guide |
| `examples/` | Labで使う containerlab / FRRouting / script の最小例 |
| `scripts/` | Linux環境でLabを実行するための補助スクリプト |
| `assets/` | 教材で参照する図、スクリーンショット、小さなpcap |

## Learning Track

Protocol Lab begins with BGP/RPKI and then expands toward the protocols that make up a web request. The full sequence is described in [ROADMAP.md](ROADMAP.md).

| Track | Labs | Outcome |
|---|---:|---|
| BGP/RPKI | 01-04 | Explain route announcements, UPDATEs, competing origins, and origin validation |
| DNS | 05-06 | Trace recursive resolution, caching, TTLs, and negative answers |
| TCP | 07-08 | Read handshakes, teardown, retransmission, windowing, and loss recovery |
| TLS / HTTP / QUIC | 09-12 | Follow an encrypted web request across transport and application layers |

日本語: Protocol Lab は BGP/RPKI から始まり、Web request を構成する DNS、TCP、TLS、HTTP、QUIC へ進みます。全12回の流れは [ROADMAP.md](ROADMAP.md) にあります。

| トラック | Lab | 到達点 |
|---|---:|---|
| BGP/RPKI | 01-04 | 経路広告、UPDATE、competing origin、origin validation を説明する |
| DNS | 05-06 | 再帰問い合わせ、cache、TTL、negative answer を追う |
| TCP | 07-08 | handshake、切断、再送、windowing、loss recovery を packet trace から読む |
| TLS / HTTP / QUIC | 09-12 | 暗号化された Web request を transport と application layer に分けて追う |
