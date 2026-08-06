# Lab 46 compiles the BPF object at image build time, so the runtime step is
# just load-attach-observe. Like Labs 43-45 everything happens inside one
# privileged container and no root is needed on your own machine.
FROM alpine:3.21

RUN apk add --no-cache \
      clang \
      llvm \
      libbpf-dev \
      linux-headers \
      bpftool \
      iproute2 \
      iputils \
      iptables \
      tcpdump

WORKDIR /lab
COPY drop_icmp.bpf.c /lab/drop_icmp.bpf.c

# -target bpf makes clang emit BPF bytecode in an ELF that libbpf can load.
RUN clang -O2 -g -target bpf -c drop_icmp.bpf.c -o drop_icmp.bpf.o

COPY observe-xdp.sh /lab/observe-xdp.sh
RUN chmod +x /lab/observe-xdp.sh

CMD ["/lab/observe-xdp.sh"]
