# Lab 43 runs entirely inside one privileged container, so the lab needs no
# root on your own machine: the container is the "host" whose network stack we
# take apart. Everything below is a plain Linux networking toolchain.
FROM alpine:3.21

RUN apk add --no-cache \
      iproute2 \
      iputils \
      tcpdump \
      bridge-utils

COPY build-topology.sh /lab/build-topology.sh
RUN chmod +x /lab/build-topology.sh

CMD ["/lab/build-topology.sh"]
