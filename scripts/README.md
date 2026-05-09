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
```

This deploys the topology, checks the expected FRRouting output, captures BGP packets, and destroys the topology.

日本語: `run bgp-01`、`run bgp-02`、`run bgp-03` は、topology の起動、FRRouting出力の検査、BGP packet capture、後片付けまで実行します。

## Individual Steps

```bash
./scripts/labctl.sh doctor bgp-01
./scripts/labctl.sh deploy bgp-01
./scripts/labctl.sh verify bgp-01
./scripts/labctl.sh capture bgp-01
./scripts/labctl.sh destroy bgp-01
```

Replace `bgp-01` with `bgp-02` or `bgp-03` to run the same lifecycle for later BGP labs.

Generated logs and packet captures are written under `assets/<lab-id>/runs/`. That directory is ignored by git.

日本語: 後続のBGP Labを実行する場合は `bgp-01` を `bgp-02` や `bgp-03` に置き換えます。生成されたログとpcapは `assets/<lab-id>/runs/` に保存されます。このディレクトリはgitには含めません。
