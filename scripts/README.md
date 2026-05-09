# Scripts

This directory contains small helpers for running Protocol Lab examples in a Linux environment.

日本語: このディレクトリには、Linux環境でProtocol Labのexampleを動かすための補助スクリプトがあります。

## Run BGP Labs

Prerequisites:

- Docker
- containerlab
- tcpdump
- tshark

Run the full lifecycle:

```bash
./scripts/labctl.sh run bgp-01
./scripts/labctl.sh run bgp-02
./scripts/labctl.sh run bgp-03
./scripts/labctl.sh run rpki-04
```

For BGP labs, this deploys the topology, checks the expected FRRouting output, captures BGP packets, and destroys the topology. For RPKI Lab 04, it deploys the topology, checks the RPKI validation states, and destroys the topology.

日本語: `run bgp-01`、`run bgp-02`、`run bgp-03` は、topology の起動、FRRouting出力の検査、BGP packet capture、後片付けまで実行します。`run rpki-04` は、topology の起動、RPKI validation state の検査、後片付けまで実行します。

## Individual Steps

```bash
./scripts/labctl.sh doctor bgp-01
./scripts/labctl.sh deploy bgp-01
./scripts/labctl.sh verify bgp-01
./scripts/labctl.sh capture bgp-01
./scripts/labctl.sh destroy bgp-01
```

Replace `bgp-01` with `bgp-02`, `bgp-03`, or `rpki-04` to run the same lifecycle for later labs. The `capture` action is available for BGP labs.

Generated logs and packet captures are written under `assets/<lab-id>/runs/`. That directory is ignored by git.

日本語: 後続のLabを実行する場合は `bgp-01` を `bgp-02`、`bgp-03`、`rpki-04` に置き換えます。`capture` action は BGP Lab で使えます。生成されたログとpcapは `assets/<lab-id>/runs/` に保存されます。このディレクトリはgitには含めません。
