# Protocol Lab — ネタ帳 (Idea Pool)

Batch 4 (Lab 43–46: K8s / mesh mTLS / VPC / eBPF) より後の候補プール。
番号は執筆時に採番する（ここでは振らない）。各ネタは既存Labと同じ
「RFCを少し読む → 最小実験 → 観察 → 自分の言葉で説明」の型に落とせることを条件に選定。
執筆済みLabは JA/EN 変換 + ドリップ公開パイプラインにそのまま乗る。

既存カバー範囲（重複回避用）: BGP基礎×3, RPKI, DNS(再帰/キャッシュ/DNSSEC/DoT-DoH/RR/views),
TCP(handshake/再送), TLS(handshake/mTLS/DANE), HTTP(基礎/redirect-cookie), QUIC, DHCP, ARP, NDP,
PMTUD, VLAN, VXLAN, GRE, WireGuard, NAT/DNAT, traceroute, QoS, IGMP, 輻輳制御, anycast, ECMP,
IPVS, OSPF, BFD, stateful FW, MSS clamp, PBR, RPF。計画済み: K8s, mesh mTLS, VPC peering, eBPF。

---

## テーマ A: コンテナ/プラットフォーム続編（Batch 4 の直接の続き）

| Working title | 学ぶこと | 観察するもの |
|---|---|---|
| Network Namespaces from Scratch: コンテナネットワークを手で作る | netns, veth pair, bridge, デフォルトルート | `ip netns` だけで Docker 相当の配線が動く様子 |
| Linux Bridge Deep Dive: Docker の下で動いているもの | FDB, learning, flooding, ageing | ブリッジがMACを学習し flood が unicast に変わる瞬間 |
| DNS in Kubernetes: CoreDNS・ndots・search domain | cluster.local, ndots:5 の副作用, search list | 1つの名前解決が5回のクエリに化ける様子 |
| Kubernetes NetworkPolicy: CNI が実装するファイアウォール | default-deny, podSelector, egress/ingress | Policy 適用前後で pod 間疎通が変わる様子 |
| Ingress / L7 Routing: Host と Path で振り分ける | host-based/path-based routing, rewrite | 同一IPへの2つのHostヘッダが別バックエンドへ届く様子 |
| GENEVE: VXLAN の次のカプセル化 | GENEVE header, TLV options, VXLAN との差 | 同一トポロジで VXLAN/GENEVE のパケットを並べて比較 |

## テーマ B: BGP/ルーティング上級（Lab 01–04, 34 の続編）

| Working title | 学ぶこと | 観察するもの |
|---|---|---|
| BGP Communities: 経路にタグを付けて政策を運ぶ | standard/large communities, community-based filtering | community を付けた経路だけ隣接ASで local-pref が変わる様子 |
| BGP Traffic Engineering: local-pref と MED の綱引き | 出方向=local-pref, 入方向=MED/prepend | 同じ2経路が設定1行で入れ替わる様子 |
| Route Reflector: iBGP フルメッシュ問題を畳む | RR, client/non-client, cluster-id, ループ防止 | フルメッシュ撤去後も経路が配布され続ける様子 |
| BGP Multihoming: 2本のアップストリームと故障切替 | primary/backup, prepend, 障害時の収束 | 片方のセッション断で全経路がもう片方へ移る様子 |
| Aggregation & Default Route: 経路表を小さく保つ技術 | aggregate-address, more-specific 優先, 0.0.0.0/0 | 集約により隣接の経路表が縮む様子と穴の危険 |
| VRF: ルーティングテーブルを複数持つ | VRF, route leaking, L3 分離 | 同じ prefix が VRF ごとに別の next-hop を持つ様子 |
| IS-IS: OSPF のきょうだいを動かす | IS-IS levels, TLV, OSPF との思想差 | 同一トポロジで OSPF と IS-IS の LSDB を見比べる |
| RIP と Count-to-Infinity: 距離ベクトルの教訓 | distance vector, split horizon, poison reverse | 経路が 16 に向かってゆっくり腐っていく様子 |

## テーマ C: L2/冗長化（Lab 26 VLAN の続編）

| Working title | 学ぶこと | 観察するもの |
|---|---|---|
| STP: ループするL2を止める木 | root bridge election, blocking port, BPDU | ループ配線がブロードキャストストームにならない理由 |
| LACP Bonding: 2本のリンクを1本に見せる | 802.3ad, hash-based分散, リンク断時の縮退 | 片リンク断でもTCPが切れない様子とハッシュ偏り |
| VRRP: デフォルトゲートウェイの故障切替 | virtual IP/MAC, priority, preempt | master 停止で backup が同じ IP/MAC を引き継ぐ瞬間 |
| LLDP: 隣が誰かをプロトコルで知る | LLDP TLV, 隣接発見, 運用での使い所 | ケーブルの向こう側の機器名とポートが見える様子 |
| ARP Spoofing とその防御: L2 の信頼モデルを壊す | gratuitous ARP, MITM の原理, 検知 | 偽ARPで通信が第三者を経由する様子（ラボ内で安全に） |

## テーマ D: IPv6 トラック（まとまった空白地帯）

| Working title | 学ぶこと | 観察するもの |
|---|---|---|
| SLAAC: ルータ広告だけでアドレスが生える | RA, prefix info, EUI-64/stable-privacy | RA 1発でホストにアドレスとルートが揃う様子 |
| DHCPv6 vs SLAAC: M/O フラグの意味 | stateful/stateless DHCPv6, RA flags | フラグの組合せでホストの挙動が変わる様子 |
| IPv6 Privacy Extensions: 追跡されないアドレス | temporary address, preferred/valid lifetime | outgoing 接続の送信元が定期的に変わる様子 |
| Happy Eyeballs: dual-stack でどちらを使うか | RFC 8305, 接続レース, フォールバック | v6 を壊した時にユーザが気づかず v4 で繋がる様子 |
| NAT64/DNS64: v6-only ネットワークから v4 の世界へ | pref64, AAAA 合成, 変換の限界 | v6-only ホストが v4-only サーバに到達する様子 |
| IPv6 Extension Headers と Fragmentation | ext header chain, v6 では中継が分割しない | 大きなパケットが送信元でだけ分割される様子 |

## テーマ E: TCP/トランスポート深掘り（Lab 07/08/30 の続編）

| Working title | 学ぶこと | 観察するもの |
|---|---|---|
| UDP: 何も保証しないことの意味 | connectionless, 消えるパケット, アプリ側の再送設計 | 損失下で TCP と UDP の挙動が分かれる様子 |
| TIME_WAIT とポート枯渇: 接続を閉じるコスト | TIME_WAIT の意味, ephemeral port, SO_REUSEADDR | 大量短命接続でポートが尽きて connect が失敗する瞬間 |
| SYN Backlog と SYN Cookies: 接続開始の防波堤 | backlog queue, SYN flood, cookies の仕組み | backlog 溢れと cookies 有効時の挙動差 |
| Nagle と Delayed ACK: 小さな書き込みが遅い理由 | Nagle algorithm, delayed ACK, 相互作用の悪夢 | 40ms 級の謎の遅延が TCP_NODELAY で消える様子 |
| CUBIC vs BBR: 輻輳制御の性格の違い | loss-based vs model-based, バッファ膨張 | 同一損失/遅延条件でスループット曲線が分かれる様子 |
| ECN: 落とさずに混雑を伝える | ECN bits, AQM との協調 | 損失ゼロのまま送信レートが下がる様子 |
| TCP Keepalive vs アプリの Heartbeat | keepalive timer, NAT timeout との関係 | アイドル接続が NAT で静かに死ぬ様子と検知 |
| SO_REUSEPORT: カーネルにロードバランスさせる | reuseport, 複数プロセス受信, ハッシュ分散 | 4プロセスに接続が均等分配される様子 |

## テーマ F: TLS/セキュリティ続編（Lab 09/15/17 の続編）

| Working title | 学ぶこと | 観察するもの |
|---|---|---|
| TLS 1.3 Session Resumption と 0-RTT | PSK, session ticket, 0-RTT の replay リスク | 再接続で handshake が丸ごと短くなる様子 |
| 証明書失効: OCSP と CRL はなぜ難しいか | revocation, OCSP stapling, soft-fail 問題 | 失効させた証明書がすぐには拒否されない現実 |
| Certificate Transparency: 全証明書は公開ログにある | CT log, SCT, 監視の使い方 | 自分のドメインの証明書発行履歴をログから掘る |
| ACME: Let's Encrypt がドメインを確認する仕組み | HTTP-01/DNS-01 challenge, 自動更新 | challenge の作成→検証→発行をパケットで追う |
| ECH: SNI を隠す最後のピース | Encrypted Client Hello, DoH との連携 | ClientHello から名前が消える before/after |
| SSH Deep Dive: もう1つのセキュアチャネル | host key, known_hosts, agent, port forwarding | 初回接続の TOFU と -L/-R トンネルの実配線 |
| IPsec (IKEv2) vs WireGuard: 2つのVPNの思想 | IKE ネゴシエーション, SA, 設定量の対比 | 同じトンネルを両方式で張って handshake を比較 |

## テーマ G: DNS 上級（Lab 05/06/13/14/41/42 の続編）

| Working title | 学ぶこと | 観察するもの |
|---|---|---|
| Zone Transfer: AXFR/IXFR とセカンダリ運用 | zone transfer, NOTIFY, serial | primary 更新が secondary へ伝播する流れ |
| Dynamic DNS Update: レコードをプロトコルで書く | RFC 2136, TSIG 認証 | nsupdate で A レコードが即時に変わる様子 |
| EDNS0 と 512 バイトの壁 | UDP サイズ制限, TC bit, TCP フォールバック | 大きな応答が truncate され TCP で取り直される様子 |
| DNS Amplification: 増幅攻撃の構造と防御 | 反射・増幅, ANY, response rate limiting | 小さなクエリが巨大な応答を生む増幅率の実測（ラボ内） |
| mDNS: .local はどう解決されているか | multicast DNS, avahi, 名前衝突 | ルータ無しの2ホストが互いを名前で見つける様子 |
| Glue Records と委任のデバッグ | delegation, glue, lame delegation | glue を壊すと解決が循環参照で死ぬ様子 |

## テーマ H: HTTP/アプリ層続編（Lab 10/11/27 の続編）

| Working title | 学ぶこと | 観察するもの |
|---|---|---|
| HTTP/3 を触る: QUIC の上の HTTP | Alt-Svc, h3 ネゴシエーション, 接続マイグレーション | curl --http3 で h2→h3 に切り替わる過程 |
| WebSocket: HTTP から双方向ストリームへ | Upgrade handshake, frame, ping/pong | 101 Switching Protocols の前後でプロトコルが変わる瞬間 |
| Reverse Proxy と X-Forwarded-For / PROXY protocol | 送信元の保存, hop 情報, 偽装リスク | proxy 経由で実クライアント IP がどう運ばれるか |
| 条件付きリクエスト: ETag と 304 の経済学 | ETag/Last-Modified, If-None-Match, CDN 再検証 | 2回目のリクエストがボディ無し 304 で返る様子 |
| gRPC on the Wire: HTTP/2 の上の RPC | HTTP/2 frames, trailers, status の運ばれ方 | 1つの RPC 呼び出しを frame 単位に分解して読む |
| CORS: ブラウザだけが従うルールをワイヤで見る | preflight, Origin, サーバ側は防御でない事実 | OPTIONS preflight の往復と curl では起きない対比 |

## テーマ I: NAT 越え / リアルタイム通信（Lab 20/40 の応用編）

| Working title | 学ぶこと | 観察するもの |
|---|---|---|
| STUN: 自分の公開アドレスを知る方法 | NAT の種類, バインディング発見 | NAT 内ホストが外から見た自分を知る往復 |
| TURN と ICE: それでも繋がらない時の最終手段 | relay, candidate 収集と優先順位 | direct / reflexive / relay 候補の選択過程 |
| WebRTC Data Channel: ブラウザ間 P2P の全部盛り | SDP, ICE, DTLS, SCTP | 2ブラウザが NAT 越しに直接繋がるまでの全パケット |
| QUIC Connection Migration: IP が変わっても切れない接続 | connection ID, path validation | WiFi→別ネットワーク切替でも接続が生き残る様子 |

## テーマ J: 運用/可観測性（Lab 19/28 の運用編）

| Working title | 学ぶこと | 観察するもの |
|---|---|---|
| NetFlow/IPFIX: パケットを見ずにトラフィックを知る | flow の定義, exporter/collector, sampling | フローレコードから「誰が何と話したか」を復元する |
| NTP: 時刻同期が TLS と DNSSEC を支えている | stratum, offset/delay, 時刻ズレの実害 | 時計を意図的にずらすと TLS 検証が壊れる様子 |
| SNMP: 枯れた監視プロトコルを読む | MIB, OID, polling vs trap | インターフェースカウンタを OID で直接引く |
| conntrack Deep Dive: ステートテーブルの中身 | conntrack entries, timeout, テーブル溢れ | NAT/FW の裏で状態が生まれ老いて消える様子 |
| tc netem: 障害を作る技術 | latency/loss/reorder/corrupt の注入 | 「再現しない不具合」をコマンド1行で再現する |
| BPF Filter 構文 Deep Dive: tcpdump を正確に絞る | BPF 式, オフセット指定, 高速化の理屈 | 同じキャプチャを粗い/精密なフィルタで取り比べる |

---

## 選定メモ

- **次バッチの推し**: テーマ A（Batch 4 と地続き）→ テーマ E（TCP深掘りは既存読者の続きとして自然）→ テーマ D（IPv6 は体系的空白で連載向き）。
- テーマ C の ARP spoofing、テーマ G の DNS amplification は攻撃系。ラボ内完結・防御視点の構成を明記して書く。
- 1ネタ = 1記事（JA/EN）としてパイプラインの供給源になる。42本 + 4本計画済みに対し、ここに約 60 本。
