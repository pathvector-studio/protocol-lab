# Reverse Path Filtering Reading Guide for Lab 39

This guide points at the material that matters for Lab 39. Reverse path filtering is the Linux implementation of *ingress filtering* — dropping packets whose source address could not legitimately have arrived on the interface they came in on. The primary references are the BCP documents that define ingress filtering plus the `rp_filter` sysctl behaviour.

日本語: この guide は Lab 39 の読みどころを整理したものです。reverse path filtering は *ingress filtering* の Linux 実装で、来たインターフェースから正当には到達し得ない送信元アドレスのパケットを落とす。主に ingress filtering を定義する BCP と、`rp_filter` sysctl の挙動を挙げます。

Target material:

- [BCP 38 / RFC 2827: Network Ingress Filtering](https://www.rfc-editor.org/rfc/rfc2827) — the anti-spoofing best practice
- [BCP 84 / RFC 3704: Ingress Filtering for Multihomed Networks](https://www.rfc-editor.org/rfc/rfc3704) — strict vs loose (feasible-path) modes
- [Linux `ip-sysctl` documentation](https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt) — the `rp_filter` values 0/1/2

## Reading Goal

Read reverse path filtering as *"would a reply to this source go back out the interface the packet came in on?"* For each incoming packet the kernel does a route lookup on its **source** address (a reverse lookup). If the best route back to that source does not use the arrival interface, the source is implausible — likely spoofed — and the packet is dropped.

日本語: reverse path filtering は「この送信元への返信は、来たインターフェースから出て行くか?」と読みます。カーネルは各入力パケットの **送信元** アドレスで route lookup(逆引き)する。その送信元への best route が到着インターフェースを使わないなら、送信元はあり得ない——たいてい詐称——ので落とす。

Start with these ideas:

- **Spoofing** = forging the source address of a packet (used in DDoS reflection, hiding origin).
- **Ingress filtering** (BCP 38) drops packets whose source can't belong on that link.
- Linux's **`rp_filter`** does this by a reverse route lookup on the source.
- Modes: `0` off, `1` **strict** (must arrive on the best-return interface), `2` **loose** (reachable via *any* interface).

## Lab #39 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | RFC 2827 (BCP 38) | ingress filtering の原則(詐称元を入口で落とす) |
| 2 | RFC 3704 (BCP 84) | strict / loose(feasible path)モードとマルチホーミング |
| 3 | Linux ip-sysctl | `rp_filter` の 0/1/2、`all`/interface の max 合成 |

## spoofing(なぜ危険か)

- 攻撃者は送信元アドレスを **偽装** できる(IP はそれを検証しない)。
- 用途: DDoS の **reflection/amplification**(偽装元=被害者にして応答を集中させる)、発信元の隠蔽、信頼 IP の詐称。
- 防ぐには、パケットが **正当にその入口から来たか** を入口で確かめる=ingress filtering。

## reverse path lookup(逆引き)

- 通常の転送は **宛先** を引く。rp_filter は追加で **送信元** を引く。
- 送信元への best route が到着インターフェースと一致するか見る。一致しなければ「その送信元はそこから来ないはず」=詐称の疑い → drop。
- Lab: 攻撃者(net B, eth2 側)が net A の `10.0.1.10` を詐称。r の `10.0.1.0/24` への route は eth1。パケットは eth2 から来た → 不一致 → strict なら drop。
- 一方、攻撃者の **本物の** 送信元 `10.0.2.10` は eth2 経由が正しい → 通る。だから rp_filter は **詐称だけ** を落とし、正当な通信は妨げない。

## strict / loose / off(rp_filter の値)

Linux ip-sysctl / RFC 3704。

| 値 | 意味 | いつ |
|---|---|---|
| `0` | off。逆引きチェックなし | 対称でない設計で誤爆を避けたいとき(要注意) |
| `1` | **strict**。到着 IF が **best return path** と一致必須 | 単一経路・対称ルーティングの網。最も強力 |
| `2` | **loose**。送信元が **いずれかの** IF から到達可能ならOK | 非対称ルーティング/マルチホーミングで strict が誤爆するとき |

- Linux の実効値は `conf.all.rp_filter` と `conf.<if>.rp_filter` の **max**。両方見て設定する(Lab は両方 1/0)。
- **非対称ルーティング注意**: 行きと戻りで別 IF を使う設計(policy routing の一部、マルチホーミング)では strict が正当なパケットも落としうる。その場合は loose か、経路を対称に設計する。

## Message から読む(Lab の出力)

| 見えるもの | 意味 |
|---|---|
| `rp_filter = 1`(all/eth2) | strict 逆引きが有効 |
| spoofed(strict)= 0 | 詐称パケットが入口で落とされた |
| legit(strict)= 3 | 本物の送信元は通った(詐称だけブロック) |
| spoofed(off)= 3 | rp_filter 無効だと詐称が転送される |

## よくある誤解

- **rp_filter が宛先を見ると思う**。見るのは **送信元**(逆引き)。宛先は通常の転送。
- **正当な通信も落とすと思う**。落とすのは「その入口から来ないはずの送信元」だけ。本物は通る。
- **strict が常に正しいと思う**。非対称ルーティングでは誤爆する。マルチホーミングは loose(2)か対称設計。
- **`conf.all` だけ設定すればよいと思う**。実効値は all と interface の **max**。両方確認する。
- **ファイアウォールと同じと思う**。rp_filter は送信元到達性の一点。stateful firewall(Lab 36)は接続状態。層が別。

## 前後の Lab とのつながり

- policy routing(Lab 38)と表裏: あちらは source で経路を選ぶ、こちらは source の妥当性を検査する。両方 **送信元** を経路判断に使う。非対称にすると rp_filter と衝突しうる。
- stateful firewall(Lab 36)と組んで境界防御を成す(片や送信元詐称、片や接続状態)。
- DDoS reflection の緩和(BCP 38)としてネット境界で広く使う。ARP/NDP(24/23)の近傍検証とは別レイヤの「本物か」チェック。
