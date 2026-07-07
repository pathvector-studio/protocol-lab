# BIND 9 + iproute2 for Protocol Lab (see dns-05 for the rationale).
#
# BIND 9.20 speaks Do53, DoT (DNS over TLS, port 853), and DoH (DNS over HTTPS,
# port 443) from one binary. The upstream image is Alpine-based (no apt-get, a
# busybox `ip`, and an ENTRYPOINT of named -u bind): install real iproute2 with
# apk, reset the ENTRYPOINT, and run named foreground (-g) so its logs reach
# `docker logs`.
FROM internetsystemsconsortium/bind9:9.20

RUN apk add --no-cache iproute2

ENTRYPOINT []
CMD ["/usr/sbin/named", "-g", "-c", "/etc/bind/named.conf", "-u", "bind"]
