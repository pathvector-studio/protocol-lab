# DNS Lab #6: Caching, TTL, and the Answer That Wasn't There

Expected time: 50 to 65 minutes  
日本語: 想定時間 50〜65分

Reading guide: [`../rfc-notes/dns-caching-ttl-negative.md`](../rfc-notes/dns-caching-ttl-negative.md)

Prerequisite: [DNS Lab 05: Recursive Resolution You Can Trace](dns-05-recursive-resolution.md)

## Goal

Lab 05 walked one name down the tree. This lab reuses the same hierarchy and asks a different question: once the resolver has an answer, **how long does it keep it, and what happens when there is no answer at all?**

You will observe three things:

- A **positive answer** whose TTL counts down while it sits in the cache.
- A **long-TTL name** that stays cached far longer than a short-TTL one.
- A **negative answer** (`NXDOMAIN`) that comes back with an SOA record and is itself cached.

日本語: Lab 05 では1つの名前を木の下へたどりました。この Lab では同じ階層を使い、別の問いを立てます。「resolver は答えをどれだけの間持ち続けるのか、そして答えが存在しないときは何が返るのか」。positive answer の TTL カウントダウン、長い TTL と短い TTL の違い、そして NXDOMAIN(negative answer)と SOA による negative caching を観察します。

By the end, you should be able to explain this table:

| Query | Result | Cached for |
|---|---|---|
| `www.example.lab` A | `203.0.113.10`, TTL 60 | 60 s (short) |
| `stable.example.lab` A | `203.0.113.20`, TTL 3600 | 3600 s (long) |
| `missing.example.lab` A | `NXDOMAIN` + `example.lab.` SOA | 300 s (SOA minimum) |

## What You Will Learn

理解したいこと:

- What a TTL is and who sets it (the authoritative zone, not the resolver).
- Why a second identical query is faster and shows a smaller TTL.
- Why records with different TTLs leave the cache at different times.
- What a negative answer (`NXDOMAIN`) looks like, and why it carries an SOA.
- How the SOA minimum controls how long a negative answer is cached (RFC 2308).

This lab does not cover:

- DNSSEC-authenticated denial of existence (NSEC/NSEC3).
- Cache poisoning or resolver security.
- Serve-stale behavior and prefetching.
- Zone transfers or dynamic updates.

## RFCで読む場所

今回の必読は以下。

| RFC | 章 | 読むポイント |
|---|---|---|
| RFC 1035 | 3.2.1, 4.1.3 | resource record と TTL フィールドの意味 |
| RFC 1035 | 7.4 | resolver が答えを cache し、TTL で捨てる仕組み |
| RFC 2308 | 1-3 | negative answer、NXDOMAIN と NODATA、SOA による negative caching |
| RFC 2308 | 5 | SOA minimum が negative cache の TTL を決めること |
| RFC 8499 | 3, 6 | TTL、authoritative TTL、negative cache の用語 |
| RFC 5737 | 3 | `203.0.113.0/24` が documentation prefix であること |

## 実験の全体像

Lab 05 と同じ5ノード構成を使う。今回は委任の連鎖よりも、resolver の cache に注目する。

```text
client ---- resolver ----+---- root  (serves ".")
         (recursive)      +---- tld   (serves "lab.")
                          +---- auth  (serves "example.lab.")

example.lab. の中身:
  www.example.lab.     A  203.0.113.10   TTL 60     (short)
  stable.example.lab.  A  203.0.113.20   TTL 3600   (long)
  missing.example.lab.  -> なし  => NXDOMAIN + SOA (negative TTL 300)
```

```mermaid
sequenceDiagram
  participant C as client
  participant R as resolver (cache)
  participant A as auth (example.lab.)

  Note over R: cache is empty
  C->>R: www.example.lab A?
  R->>A: www.example.lab A?
  A-->>R: 203.0.113.10 TTL 60
  R-->>C: 203.0.113.10 TTL 60
  Note over R: cached, TTL counting down

  C->>R: www.example.lab A? (again, 3s later)
  R-->>C: 203.0.113.10 TTL 57
  Note over R: no upstream query; served from cache

  C->>R: missing.example.lab A?
  R->>A: missing.example.lab A?
  A-->>R: NXDOMAIN + example.lab. SOA
  R-->>C: NXDOMAIN (negative-cached for SOA minimum 300)
```

`203.0.113.0/24` は RFC 5737 の documentation prefix。外部へ出さず Lab 内だけで使う。

## 必要なもの

推奨環境:

- Linux / WSL2 / Linux VM
- Docker
- containerlab
- BIND9 container image
- netshoot container image (client tools)

使用イメージ:

- `protocol-lab/bind9:9.20`(`examples/dns-06/Dockerfile` からローカルビルド。`internetsystemsconsortium/bind9:9.20` に `iproute2` を足し、named を foreground で動かすだけの薄いラッパー)
- `nicolaka/netshoot:latest`

上流の ISC BIND イメージには `ip` コマンドが入っておらず、containerlab が `exec` で使う `ip addr add` が通らない。そのため `iproute2` を足したイメージをローカルにビルドしてから使う。`run.sh` は deploy の前に自動でビルドする。Lab 05 を先に実行済みなら、同じ `protocol-lab/bind9:9.20` イメージが再利用される。

## 実行手順

この手順は、containerlab を実行する Linux 環境の中で行う。

このリポジトリを持っている場合は、Linux 環境で検証スクリプトを実行できる。

```bash
./scripts/labctl.sh run dns-06
```

`labctl.sh run dns-06` は、topology deploy、TTL カウントダウンの確認、NXDOMAIN と SOA の確認、destroy まで行う。

### 1. 作業ディレクトリへ移動する

```bash
cd protocol-lab/examples/dns-06
```

### 2. ゾーンの TTL を読む

実験の前に、authoritative ゾーンの TTL を読む。

```bash
cat auth/db.example.lab
```

読み方:

- `www.example.lab.` は TTL `60`。短い。
- `stable.example.lab.` は TTL `3600`。長い。
- `missing.example.lab.` のレコードは **ない**。だから NXDOMAIN になる。
- SOA の最後の数字 `300` が negative cache の TTL(RFC 2308)。

### 3. 起動する

まず BIND イメージ(iproute2 入り)をビルドしてから deploy する。

```bash
docker build -t protocol-lab/bind9:9.20 .
sudo containerlab deploy -t dns-06.clab.yml
docker ps --format "table {{.Names}}\t{{.Status}}"
```

`clab-dns-06-{root,tld,auth,resolver,client}` が起動していることを確認する。

### 4. TTL のカウントダウンを見る

同じ名前を、少し間を空けて2回聞く。

```bash
docker exec -it clab-dns-06-client dig @10.0.0.1 www.example.lab A
sleep 3
docker exec -it clab-dns-06-client dig @10.0.0.1 www.example.lab A
```

見るポイント:

- 1回目: `www.example.lab. 60 IN A 203.0.113.10`、`Query time` はやや大きい。
- 2回目: TTL が `57` 前後に減っている。`Query time: 0 msec` に近い。

TTL は authoritative が付けた「この答えを最大この秒数キャッシュしてよい」という値。resolver は cache に入れた瞬間からカウントダウンし、client にはその残り秒数を見せる。

TTL が `0` になるまで待って(このLabなら60秒)もう一度聞くと、TTL は `60` に戻る。resolver が cache を捨てて、auth に問い直したから。

```bash
sleep 60
docker exec -it clab-dns-06-client dig @10.0.0.1 www.example.lab A
```

### 5. 長い TTL と短い TTL を比べる

```bash
docker exec -it clab-dns-06-client dig @10.0.0.1 stable.example.lab A
```

見るポイント:

- `stable.example.lab. 3600 IN A 203.0.113.20`。
- 3秒後に聞き直しても、`stable` はまだ大きな TTL(例 `3597`)。`www` よりずっと長く cache に残る。

同じ resolver、同じゾーンでも、レコードごとに cache の寿命が違う。決めるのは authoritative の TTL。

### 6. 存在しない名前を聞く(negative answer)

```bash
docker exec -it clab-dns-06-client dig @10.0.0.1 missing.example.lab A
```

期待する確認ポイント:

```text
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: ...

;; AUTHORITY SECTION:
example.lab.  300  IN  SOA  ns.example.lab. admin.example.lab. 1 3600 900 604800 300
```

読み方:

- `status: NXDOMAIN` は「この名前は存在しない」。
- `ANSWER SECTION` は空。代わりに `AUTHORITY SECTION` にゾーンの SOA が入る。
- SOA の最後の数字(`300`)が、この negative answer をキャッシュしてよい秒数。

もう一度すぐ聞くと、resolver は auth に問い直さず、negative cache から NXDOMAIN を返す。

```bash
docker exec -it clab-dns-06-client dig @10.0.0.1 missing.example.lab A
```

`Query time` が下がっていれば、negative cache が効いている。

### 7. resolver のログで cache の効き目を確かめる

resolver は受け取った query をログに出す。cache hit では上流(auth)への再問い合わせが起きない。

```bash
docker logs clab-dns-06-resolver 2>&1 | grep query | tail
```

client からの query は毎回記録されるが、cache にある間は root/tld/auth への iterative query は繰り返されない。

## 期待出力

完全一致よりも以下が取れることを重視する。

### `dig www.example.lab`(2回)

- 1回目 TTL `60`、2回目 TTL が減っている。
- 2回目の `Query time` が小さい。

### `dig stable.example.lab`

- TTL `3600`。`www` よりはるかに長い。

### `dig missing.example.lab`

- `status: NXDOMAIN`。
- `AUTHORITY SECTION` に `example.lab.` の SOA。

## なぜそう動くのか

TTL(time to live)は、authoritative zone が各レコードに付ける「キャッシュ可能な最大秒数」。resolver はレコードを cache に入れた瞬間から TTL を減らし、`0` になったら捨てる。だから:

- 2回目が速いのは、cache から答えているから。
- 見える TTL が減るのは、cache に入ってからの経過時間を引いているから。
- `stable`(TTL 3600)が長く残るのは、authoritative がそう決めたから。

答えが「ない」場合も、resolver は毎回問い直したくない。RFC 2308 は、negative answer(NXDOMAIN や NODATA)も cache する仕組みを定めている。authoritative は否定応答に **SOA レコード** を添え、その **minimum フィールド**(と SOA 自身の TTL の小さい方)が negative cache の寿命になる。このLabでは SOA minimum が `300` なので、`missing.example.lab` の NXDOMAIN は最大 300 秒キャッシュされる。

つまり cache は positive でも negative でも働く。違うのは、寿命を決める値がどこから来るか(通常レコードは各 RR の TTL、否定応答は SOA)。

## 詰まりやすい点

- **TTL を resolver が決めると思う**。TTL を決めるのは authoritative zone。resolver は減らして捨てるだけ。
- **TTL が減らないように見える**。2回の query が同じ秒内だと差が出ない。数秒空ける。
- **NXDOMAIN と NODATA を混同する**。NXDOMAIN は「名前そのものが無い」。NODATA は「名前はあるが、その型のレコードが無い」(例: A は無いが MX はある)。どちらも SOA を添えて negative cache される。
- **negative answer に SOA が付く理由**。SOA が無いと resolver は「どれだけキャッシュしてよいか」を決められない。
- **short TTL は速く更新できるが負荷が高い**。TTL は鮮度とキャッシュ効率のトレードオフ。
- このLabの階層は DNSSEC 署名していない。実運用の否定応答は NSEC/NSEC3 で「本当に無い」ことを証明することがある(このLabの範囲外)。

## 後片付け

```bash
sudo containerlab destroy -t dns-06.clab.yml --cleanup
```

`labctl.sh run dns-06` を使った場合は、スクリプトが最後に destroy する。

## 確認問題

1. TTL を決めるのは authoritative server か resolver か。resolver は TTL に対して何をするか。
2. 同じ名前の2回目の query が速く、TTL が小さく見えるのはなぜか。
3. `www`(TTL 60)と `stable`(TTL 3600)で cache の寿命が違うのはなぜか。
4. `missing.example.lab` の応答の `status` は何か。`ANSWER` と `AUTHORITY` には何が入るか。
5. negative answer に SOA が付くのはなぜか。negative cache の寿命は何で決まるか。
6. NXDOMAIN と NODATA の違いを、例を挙げて説明せよ。

## References

- [RFC 1035: Domain Names - Implementation and Specification](https://www.rfc-editor.org/rfc/rfc1035)
- [RFC 2308: Negative Caching of DNS Queries (DNS NCACHE)](https://www.rfc-editor.org/rfc/rfc2308)
- [RFC 8499: DNS Terminology](https://www.rfc-editor.org/rfc/rfc8499)
- [RFC 5737: IPv4 Address Blocks Reserved for Documentation](https://www.rfc-editor.org/rfc/rfc5737)
- [BIND 9 Administrator Reference Manual](https://bind9.readthedocs.io/en/latest/)
