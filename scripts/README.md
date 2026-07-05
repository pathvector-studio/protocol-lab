# Scripts

This directory contains small helpers for running Protocol Lab examples in a Linux environment.

日本語: このディレクトリには、Linux環境でProtocol Labのexampleを動かすための補助スクリプトがあります。

## Install the Tooling (Ubuntu/Debian)

```bash
sudo bash scripts/install-lab-tools.sh --pull
```

This installs Docker, containerlab, tshark, tcpdump, jq, and curl, enables the Docker service, and adds you to the `docker` group. Log out and back in (or run `newgrp docker`) afterward, then check with `./scripts/labctl.sh doctor tcp-07`. Omit `--pull` to skip pre-downloading the lab base images.

日本語: `install-lab-tools.sh` は Docker、containerlab、tshark などをまとめて導入し、Docker サービスを有効化して、あなたを `docker` グループに追加します。実行後は再ログイン(または `newgrp docker`)し、`./scripts/labctl.sh doctor tcp-07` で確認します。`--pull` を外すとイメージの先読みを省けます。

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

Replace `bgp-01` with any lab id to run the same lifecycle: `bgp-02`, `bgp-03`, `rpki-04`, `dns-05`, `dns-06`, `tcp-07`, `tcp-08`, `tls-09`, `http-10`, `quic-11`, `e2e-12`. The `capture` action is available for BGP labs.

Generated logs and packet captures are written under `assets/<lab-id>/runs/`. That directory is ignored by git.

日本語: 後続のLabを実行する場合は `bgp-01` を `bgp-02`、`bgp-03`、`rpki-04` に置き換えます。`capture` action は BGP Lab で使えます。生成されたログとpcapは `assets/<lab-id>/runs/` に保存されます。このディレクトリはgitには含めません。
