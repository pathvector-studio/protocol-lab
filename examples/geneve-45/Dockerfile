# Lab 45 runs both encapsulations side by side inside one privileged container,
# so it needs no root on your own machine and no containerlab topology.
FROM alpine:3.21

RUN apk add --no-cache \
      iproute2 \
      iputils \
      tcpdump

COPY compare-encap.sh /lab/compare-encap.sh
RUN chmod +x /lab/compare-encap.sh

CMD ["/lab/compare-encap.sh"]
