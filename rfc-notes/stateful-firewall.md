# Stateful Firewall Reading Guide for Lab 36

This guide points at the material that matters for Lab 36. A stateful firewall is a mechanism (Linux netfilter/conntrack here) rather than a single RFC, so the primary references are the connection-tracking model plus RFC 2979's definition of firewall behaviour and the TCP state machine that conntrack mirrors.

日本語: この guide は Lab 36 の読みどころを整理したものです。ステートフルファイアウォールは単一 RFC ではなく仕組み(ここでは Linux netfilter/conntrack)なので、主に connection tracking の考え方、RFC 2979 のファイアウォール挙動の定義、そして conntrack が写し取る TCP 状態機械を挙げます。

Target material:

- [RFC 2979: Behavior of and Requirements for Internet Firewalls](https://www.rfc-editor.org/rfc/rfc2979) — what a firewall must do (transparency, consistency)
- [RFC 7857: Updates to NAT Behavioral Requirements](https://www.rfc-editor.org/rfc/rfc7857) — connection-tracking timeouts and state (shared with NAT)
- [RFC 9293: Transmission Control Protocol](https://www.rfc-editor.org/rfc/rfc9293) — the TCP state machine conntrack follows

## Reading Goal

Read a stateful firewall as *"decide by the connection, not just the packet."* A stateless filter judges each packet alone (addresses, ports, flags). A stateful firewall keeps a **connection-tracking table**: it remembers flows it has seen, so a return packet is recognised as part of an allowed conversation and let through, while an identical-looking packet that starts a *new* unsolicited conversation is dropped.

日本語: ステートフルファイアウォールは「パケット単体でなく接続で判断する」と読みます。ステートレスなフィルタは各パケットを単独で(アドレス・ポート・フラグ)判定する。ステートフルは **connection-tracking テーブル** を持ち、見た flow を覚えるので、戻りパケットは許可済み会話の一部と認識して通し、見た目が同じでも *新規* の一方的な会話を始めるパケットは落とす。

Start with these ideas:

- **conntrack** records every flow the box forwards, in both directions, as one entry.
- A packet's **ctstate** — NEW, ESTABLISHED, RELATED, INVALID — is what the policy matches on.
- Typical policy: **default DROP**, allow **ESTABLISHED,RELATED**, allow **NEW only from the trusted side**.
- The reply to an allowed connection is permitted by *state*, not by a rule that names it.

## Lab #36 で読む場所

| 優先 | 資料 | 読む目的 |
|---|---|---|
| 1 | RFC 2979 | firewall の要件(透過性・一貫性)、default-deny の考え |
| 2 | RFC 9293 §3.3 | TCP 状態機械(conntrack が写す SYN→ESTABLISHED→…) |
| 3 | RFC 7857 | conntrack のタイムアウト/状態(NAT と共通の基盤) |

## stateless と stateful

- **stateless**: 各パケットを単独で判定(送信元/宛先/ポート/フラグ)。戻りを通すには「戻り用の穴」を明示的に開ける必要があり、広くなりがち。
- **stateful**: **flow** を追跡し、戻りは「既存会話の一部」として自動で通す。inbound の穴を開けずに outbound とその応答だけ許せる。
- 現代のファイアウォールは基本 stateful。Linux では **netfilter + conntrack** が担う。

## conntrack のエントリ

- box を通る各 flow を、**双方向を1エントリ**として記録する。Lab の例:

```text
tcp 6 ... src=10.0.9.2 dst=10.0.8.2 sport=38018 dport=80
          src=10.0.8.2 dst=10.0.9.2 sport=80    dport=38018 [ASSURED]
```

- 1行目は「行き」(client→server)、2行目は自動で導かれる「戻り」(server→client)。だから戻りパケットは即 ESTABLISHED と分かる。
- `[ASSURED]` は双方向にパケットが流れ、エントリが確立したことを示す。

## ctstate(ポリシーが判定する状態)

- **NEW**: その flow の最初のパケット(TCP なら SYN)。会話を始める。
- **ESTABLISHED**: すでに双方向で見た flow に属するパケット。
- **RELATED**: 既存 flow に関連する別 flow(例: FTP データ、ICMP エラー)。
- **INVALID**: どの flow にも当てはまらない(壊れた/順序外)。ふつう drop。
- Lab のポリシー:
  1. `--ctstate ESTABLISHED,RELATED -j ACCEPT`(会話の続き・関連は通す)
  2. `-i eth1 --ctstate NEW -j ACCEPT`(**内側から**始まる新規のみ許可)
  3. `-P FORWARD DROP`(それ以外は落とす)

## なぜ client は通り server は通らないのか

- **client → server**: SYN は内側(eth1)からの **NEW** → 規則2で許可。server の応答は **ESTABLISHED** → 規則1で許可。会話成立。
- **server → client**: server が始める SYN は外側からの **NEW**。規則2は内側(eth1)限定なので当てはまらず、規則1(ESTABLISHED)にも当てはまらない → default DROP。
- 面白い点: どちらの場合も「server→client 向き」のパケットは流れる。違いは **conntrack の状態**: 許可済み会話の応答(ESTABLISHED)か、勝手な新規(NEW)か。向きではなく **状態** が運命を決める。

## Message から読む(Lab の出力)

| 見えるもの | 意味 |
|---|---|
| `policy DROP` | 既定は落とす(明示許可のみ通す) |
| `ctstate RELATED,ESTABLISHED ACCEPT` | 既存会話とその関連を許可 |
| `eth1 ... ctstate NEW ACCEPT` | 内側からの新規接続のみ許可 |
| client→server: `ok` | 内側発の会話は成立 |
| server→client: `blocked` | 外側発の勝手な新規は遮断 |
| conntrack の双方向1エントリ | 戻りが ESTABLISHED と分かる根拠 |

## よくある誤解

- **戻り用の穴を開ける必要があると思う**。stateful では不要。戻りは state で自動許可。穴を開けると逆に危険。
- **向きで許可が決まると思う**。決めるのは **conntrack の状態**。同じ server→client 向きでも ESTABLISHED は通り NEW は落ちる。
- **default ACCEPT で個別に塞ぐ**。逆。**default DROP** にして必要な物だけ開けるのが原則(RFC 2979 の deny-by-default)。
- **NAT と同じと思う**。基盤(conntrack)は共通だが、NAT は変換、firewall は許可判定。目的が別(Lab 20 と対比)。
- **UDP はステートレスだから追えないと思う**。conntrack は UDP も擬似 flow として追う(タイムアウトで消える)。

## 前後の Lab とのつながり

- NAT(Lab 20)と同じ conntrack を土台にするが、こちらは **ポリシー(default-drop + state)** が主題。
- TCP(Lab 07/08)の状態機械を conntrack が写す。SYN=NEW、確立後=ESTABLISHED。
- RELATED は ICMP(Lab 19/25 の frag-needed 等)やマルチ flow プロトコルの許可に効く。
