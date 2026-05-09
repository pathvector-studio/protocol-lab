# Examples

This directory contains runnable examples used by the labs. They are intentionally small so you can inspect every config file before starting a topology.

日本語: このディレクトリには、Labで使う実行可能な最小例を入れています。topologyを起動する前に、設定ファイルを読み切れるサイズに保っています。

## Available Examples

- [`bgp-01/`](bgp-01/): a two-router eBGP topology using FRRouting and containerlab.
- [`bgp-02/`](bgp-02/): the same two-router eBGP shape, with route withdrawal and reannouncement.
- [`bgp-03/`](bgp-03/): a three-router eBGP topology with two origins for the same prefix.
- [`rpki-04/`](rpki-04/): a local RPKI origin validation lab using FRRouting, StayRTR, and containerlab.

## Safety

Examples are designed for closed local environments. They use documentation prefixes and private ASNs. Do not connect these lab topologies to a production network or advertise their routes to the public Internet.

日本語: Examplesは閉じたローカル環境で動かす前提です。documentation prefix と private ASN を使います。本番ネットワークへ接続したり、実インターネットへ経路広告したりしないでください。
