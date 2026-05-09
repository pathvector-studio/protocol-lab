# Labs

Labs are hands-on lessons. Each one focuses on a small protocol concept, points to the relevant RFC sections, runs a minimal experiment, and asks you to explain what you observed.

日本語: Labs は手を動かす教材です。1つのLabでは小さな概念に絞り、対応するRFCを読み、最小実験を動かし、観察結果を自分の言葉で説明します。

## Start with BGP Lab 01

- [BGP Lab 01: One Prefix Announcement You Can Explain](bgp-01-as-prefix-announcement.md)
- [BGP Lab 02: Watch a Route Appear, Disappear, and Come Back](bgp-02-update-nexthop-withdrawal.md)
- [BGP Lab 03: Competing Origins and the First Route-Leak Question](bgp-03-competing-origins-route-leaks.md)

Expected time: 45 to 60 minutes per lab.

For the full sequence, see the [Protocol Lab Roadmap](../ROADMAP.md).

You will build a small eBGP topology and explain one route:

```text
203.0.113.0/24 via 10.0.0.1, AS_PATH 65001, ORIGIN IGP
```

日本語: まず BGP Lab 01 から始めてください。2台の仮想ルータで eBGP を動かし、1本の経路を RFC 4271 の用語で説明します。次に Lab 02 で route の出現と取り下げを観察し、Lab 03 で同じ prefix が複数の origin AS から見える状態を作ります。全体像は [Protocol Lab Roadmap](../ROADMAP.md) を見てください。

## Lab Shape

Most labs follow this rhythm:

1. What you will understand
2. RFC sections to read
3. A small experiment
4. Logs, tables, or packets to observe
5. Why the protocol behaves that way
6. Common misunderstandings
7. Review questions
8. What to read or try next

日本語: どのLabも「理解すること、読むRFC、実験、観察、理由、誤解、確認問題、次に進むもの」という流れで読めるようにします。
