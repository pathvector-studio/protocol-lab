# BIND 9 + iproute2 for Protocol Lab (see dns-05 for the rationale).
#
# The auth node signs example.lab (with a TLSA record) and serves it. The
# upstream ISC image is Alpine-based (no apt-get, busybox ip, a named
# ENTRYPOINT): install real iproute2 with apk, reset the ENTRYPOINT, and run
# named foreground so its logs reach `docker logs`.
FROM internetsystemsconsortium/bind9:9.20

RUN apk add --no-cache iproute2

ENTRYPOINT []
CMD ["/usr/sbin/named", "-g", "-c", "/etc/bind/named.conf", "-u", "bind"]
