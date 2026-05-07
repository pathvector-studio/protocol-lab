# Scripts

This directory contains small helpers for running Protocol Lab examples in a Linux environment.

日本語: このディレクトリには、Linux環境でProtocol Labのexampleを動かすための補助スクリプトがあります。

## Run BGP Lab 01

Prerequisites:

- Docker
- containerlab
- tcpdump
- tshark

Run the full lifecycle:

```bash
./scripts/labctl.sh run bgp-01
```

This deploys the topology, waits for the BGP route, checks the expected FRRouting output, captures BGP packets, and destroys the topology.

日本語: `run bgp-01` は、topology の起動、BGP経路の確認、FRRouting出力の検査、BGP packet capture、後片付けまで実行します。

## Individual Steps

```bash
./scripts/labctl.sh doctor bgp-01
./scripts/labctl.sh deploy bgp-01
./scripts/labctl.sh verify bgp-01
./scripts/labctl.sh capture bgp-01
./scripts/labctl.sh destroy bgp-01
```

Generated logs and packet captures are written under `assets/bgp-01/runs/`. That directory is ignored by git.

日本語: 生成されたログとpcapは `assets/bgp-01/runs/` に保存されます。このディレクトリはgitには含めません。
