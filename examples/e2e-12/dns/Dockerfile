# BIND 9 + iproute2 for Protocol Lab (see dns-05 for the rationale).
#
# The upstream image is now Alpine-based: no apt-get, a busybox `ip`, and an
# ENTRYPOINT of ["/usr/sbin/named","-u","bind"]. Install real iproute2 with
# apk, reset the ENTRYPOINT, and run named foreground (-g) so its query log
# reaches `docker logs`.
FROM internetsystemsconsortium/bind9:9.20

RUN apk add --no-cache iproute2

ENTRYPOINT []
CMD ["/usr/sbin/named", "-g", "-c", "/etc/bind/named.conf", "-u", "bind"]
