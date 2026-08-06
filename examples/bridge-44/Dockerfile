# Lab 44, like Lab 43, runs entirely inside one privileged container, so it
# needs no root on your own machine. Same toolchain, one more namespace: the
# third port is what makes flooding visible.
FROM alpine:3.21

RUN apk add --no-cache \
      iproute2 \
      iputils \
      tcpdump

COPY observe-bridge.sh /lab/observe-bridge.sh
RUN chmod +x /lab/observe-bridge.sh

CMD ["/lab/observe-bridge.sh"]
