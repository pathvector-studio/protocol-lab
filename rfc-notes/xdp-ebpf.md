# XDP and eBPF Reading Guide for Lab 46

This guide points at the material that matters for Lab 46. XDP is a kernel mechanism, not a protocol, so there is no RFC — the references are the kernel documentation and the BPF manual page.

日本語: この guide は Lab 46 の読みどころを整理したものです。XDP はプロトコルではなくカーネルの仕組みなので RFC はありません。カーネルのドキュメントと man page が主資料です。

Target material:

- [XDP — kernel documentation](https://docs.kernel.org/networking/af_xdp.html) and [BPF documentation index](https://docs.kernel.org/bpf/)
- [bpf(2) manual page](https://man7.org/linux/man-pages/man2/bpf.2.html) — program load, maps, the verifier
- [bpftool-prog(8)](https://man7.org/linux/man-pages/man8/bpftool-prog.8.html) and [bpftool-net(8)](https://man7.org/linux/man-pages/man8/bpftool-net.8.html)
- [tcpdump(1)](https://man7.org/linux/man-pages/man1/tcpdump.1.html) — where in the stack it taps

## Reading Goal

For this lab, read XDP as *a hook that runs before the packet becomes a packet*. Everything the kernel normally does with an incoming frame — allocating an `sk_buff`, running netfilter, delivering to a socket, letting `tcpdump` copy it — happens after XDP has already returned a verdict. So the interesting property of XDP is not that it is fast. It is that it is **early**, and early means invisible to everything downstream.

日本語: このLabでは、XDP を「パケットがパケットになる前に走るフック」として読みます。カーネルが受信フレームに対して普通にやること——`sk_buff` の確保、netfilter の実行、ソケットへの配送、`tcpdump` によるコピー——は、すべて XDP が判定を返した *後* に起きます。だから XDP の面白い性質は「速い」ことではなく **「早い」** ことで、早いということは、それ以降の全部から見えないということです。

Start with these ideas:

- **The verdict set is tiny.** `XDP_PASS`, `XDP_DROP`, `XDP_TX`, `XDP_REDIRECT`, `XDP_ABORTED`. That is the whole vocabulary.
- **The verifier is not a linter.** It refuses to load a program it cannot *prove* safe: bounded loops, no unchecked pointer arithmetic, every read inside `data`..`data_end`. A missing bounds check is a load failure, not a crash later.
- **Maps are the only way in and out.** A BPF program cannot call into userspace. It writes to a map; userspace reads the map. In this lab that map is how you prove the program ran.
- **Loading and attaching are separate.** A loaded program sits in the kernel doing nothing until it is attached to a hook.
- **`generic` mode is a fallback.** Native XDP runs in the driver; `xdpgeneric` runs in the stack's receive path instead. Slower, but it works everywhere, which is what a lab needs.
- **Compare against netfilter deliberately.** `iptables -j DROP` reaches the same outcome from a different place in the path, and the observable difference between them is the whole lesson.

日本語の要点:

- 判定は `XDP_PASS` / `XDP_DROP` / `XDP_TX` / `XDP_REDIRECT` / `XDP_ABORTED` の5つだけ。
- verifier は lint ではない。安全だと **証明できない** プログラムはロード自体を拒否する。境界チェック漏れは「後でクラッシュ」ではなく「ロード失敗」。
- 出入り口はマップだけ。BPF プログラムはユーザ空間を呼べない。マップに書き、ユーザ空間が読む。この Lab ではそのマップが「プログラムが実際に走った証拠」になる。
- ロードとアタッチは別。ロードしただけのプログラムはどのフックにも繋がっておらず何もしない。
- `generic` モードは代替手段。native XDP はドライバ内で走るが、`xdpgeneric` はスタックの受信経路で走る。遅いがどこでも動くので Lab 向き。
- netfilter との比較が本題。`iptables -j DROP` は経路の別の場所から同じ結果に到達する。その **観測できる差** が学ぶべきこと。

## What To Skip

AF_XDP sockets and zero-copy, `XDP_REDIRECT` and CPU maps, BTF and CO-RE portability, tail calls, and the tc/BPF (`clsact`) hook. Skip performance numbers entirely — this lab measures visibility, not throughput.

日本語: AF_XDP ソケットと zero-copy、`XDP_REDIRECT` と CPU map、BTF/CO-RE による可搬性、tail call、tc/BPF(`clsact`)フックは範囲外。性能の数字も扱いません(この Lab が測るのはスループットではなく可視性)。

## Questions To Hold While Reading

- Where does XDP sit relative to `sk_buff` allocation, netfilter, and tcpdump's tap point?
- Why does the verifier insist on a `data_end` check before every dereference?
- If a packet vanishes and no capture shows it, how do you prove *what* removed it?
- Both XDP and iptables can drop the same packet. What can you observe that tells them apart?

日本語:

- XDP は `sk_buff` の確保・netfilter・tcpdump のタップ点に対して、どこに位置するか。
- verifier が参照前の `data_end` チェックを要求するのはなぜか。
- パケットが消えてどのキャプチャにも出ないとき、「何が消したか」をどう証明するか。
- XDP も iptables も同じパケットを落とせる。両者を区別できる観測は何か。
