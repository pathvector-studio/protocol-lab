# TCP MSS Clamping Reading Guide for Lab 37

This guide points at the material that matters for Lab 37. MSS clamping is an operational fix built on TCP's Maximum Segment Size option and the same Path MTU problem from Lab 25 — a router rewrites the MSS in passing SYNs so endpoints never send segments too big for the path.

日本語: この guide は Lab 37 の読みどころを整理したものです。MSS clamping は、TCP の Maximum Segment Size オプションと Lab 25 の Path MTU 問題の上に立つ運用的な対処です——ルータが通過する SYN の MSS を書き換え、endpoint が path に大きすぎる segment を送らないようにする。

Target material:

- [RFC 9293: Transmission Control Protocol §3.7.1](https://www.rfc-editor.org/rfc/rfc9293) — the MSS option and how endpoints choose segment size
- [RFC 1191: Path MTU Discovery](https://www.rfc-editor.org/rfc/rfc1191) — the mechanism MSS clamping backstops
- [RFC 2923: TCP Problems with Path MTU Discovery](https://www.rfc-editor.org/rfc/rfc2923) — the blackhole failure clamping avoids

## Reading Goal

Read MSS clamping as *"tell both ends the safe segment size up front, so they never rely on PMTU Discovery working."* Each TCP endpoint advertises an MSS in its SYN based on its *local* interface MTU — it cannot know about a smaller link deeper in the path. A router on the path *does* know its own link is smaller, so it edits the MSS option downward as the SYN passes. Both ends then agree on a size that fits everywhere.

日本語: MSS clamping は「安全な segment サイズを最初に両端へ伝え、PMTU Discovery が効くことに頼らせない」ものとして読みます。各 TCP endpoint は SYN で *自分の* インターフェース MTU に基づく MSS を広告する——path の奥の細いリンクは知りようがない。path 上のルータは自分のリンクが細いと知っているので、SYN 通過時に MSS を下げて書き換える。両端はどこでも収まるサイズで合意する。

Start with these ideas:

- **MSS** = the largest TCP payload an endpoint will accept in one segment; sent in the SYN, derived from local MTU (MTU − 40 for IPv4/TCP headers).
- The SYN MSS reflects only the **local** MTU, blind to a smaller link on the path.
- **PMTUD** (Lab 25) discovers the smaller link via ICMP — but ICMP is often filtered, causing a **blackhole**.
- **Clamping** edits the SYN's MSS at a router to the path's smallest MTU − 40, so segments always fit.

## Lab #37 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | RFC 9293 §3.7.1 | MSS option、endpoint の segment サイズ決定 |
| 2 | RFC 1191 | PMTUD(clamping が補う本来の仕組み) |
| 3 | RFC 2923 | PMTUD の blackhole 問題(clamping の動機) |

## MSS(Maximum Segment Size)

RFC 9293 §3.7.1。

- MSS = TCP が1 segment で受け取る最大ペイロード。**SYN でのみ** 広告する(データではなく接続確立時)。
- 値は **ローカル MTU − 40**(IPv4 20 + TCP 20)。MTU 1500 → MSS 1460。
- 両端が自分の MSS を伝え合い、送信側は相手の MSS を上限に segment を切る。
- 弱点: 各端は **自分のインターフェース MTU** しか知らない。path の途中に細いリンクがあっても、SYN の MSS はそれを反映しない。

## path の細いリンクと PMTUD

RFC 1191 / Lab 25。

- segment が細いリンクに来て、DF(Don't Fragment)付きで大きすぎると、ルータは通せず **ICMP "fragmentation needed"** を送り返す(実 MTU 付き)。送信側はそれを見て segment を縮める。これが **PMTUD**。
- 正常なら PMTUD が解決するが……

## PMTUD の blackhole(clamping の動機)

RFC 2923。

- ICMP が **フィルタされている**(ファイアウォールが ICMP を落とす、片方向)と、送信側は "fragmentation needed" を受け取れない。
- すると送信側は大きすぎる segment を送り続け、細いリンクで捨てられ続ける——**blackhole**。接続はハングする(小さいデータは通るのに大きい転送だけ止まる、という厄介な症状)。
- MSS clamping はこの依存を断つ: PMTUD が効かなくても、最初から収まるサイズで送らせる。

## MSS clamping(この Lab)

- path 上のルータが、通過する **SYN の MSS option** を書き換える。
- Linux: `iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu`。
  - `--clamp-mss-to-pmtu`: 送出インターフェースの MTU − 40 に、MSS がそれより大きければ下げる。
  - 固定値 `--set-mss N` も可能。
- Lab: client の SYN は MSS 1460(1500 − 40)。r の egress(server 側)は MTU 1400 なので、clamping で MSS を **1360**(1400 − 40)に書き換える。両端は 1360 以下で送るので、細いリンクでも常に収まる。
- SYN だけを書き換えれば十分(MSS は SYN でのみネゴシエートされる)。以降のデータ segment はその合意に従う。

## Message から読む(Lab の出力)

| 見えるもの | 意味 |
|---|---|
| SYN `options [mss 1460]`(clamp 前) | client のローカル MTU(1500)由来 |
| `TCPMSS clamp to PMTU`(mangle FORWARD) | ルータが SYN の MSS を書き換える規則 |
| SYN `mss 1360`(clamp 後) | 細いリンク(1400)に合わせて下げられた |
| r eth2 `mtu 1400` | path の最小 MTU |

## よくある誤解

- **MSS と MTU を混同する**。MTU は L3(IP パケット全体)、MSS は TCP ペイロード。IPv4 では MSS = MTU − 40。
- **MSS はデータごとに交渉すると思う**。**SYN でのみ**。以降は固定。
- **PMTUD があれば十分と思う**。ICMP フィルタで blackhole し得る。clamping はその保険。
- **両端で MTU を下げれば良いと思う**。奥の細いリンクは端末から見えない。**path 上のルータ**が書き換えるのが要点。
- **clamping が全 segment を書き換えると思う**。SYN の MSS option だけ。データはその合意に従う。
- **UDP にも効くと思う**。MSS は TCP の概念。UDP は別(アプリ側で PMTU を扱う)。

## 前後の Lab とのつながり

- Lab 25(MTU / PMTUD)の直接の続き。あちらの ICMP frag-needed が blackhole すると、こちらの clamping が要る。
- トンネル(WireGuard 16 / VXLAN 18 / GRE 21)は追加ヘッダで実効 MTU を下げるので、実運用で clamping が頻用される。
- 状態的なファイアウォール(Lab 36)が ICMP を落とすと PMTUD が壊れる——RELATED で ICMP エラーを通す/または clamp する、という運用判断につながる。
