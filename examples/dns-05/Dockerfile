# Thin wrapper over the ISC BIND 9 image for Protocol Lab.
#
# Why this exists:
#   - The upstream image (now built FROM alpine) ships only a busybox `ip`.
#     containerlab assigns the lab interface addresses with `ip addr add ...`
#     via exec, so we install real iproute2 here for predictable behaviour.
#   - The upstream image sets ENTRYPOINT ["/usr/sbin/named","-u","bind"] and
#     CMD ["-f", ...] (foreground but logging to a file). We reset ENTRYPOINT
#     and run named with `-g` so it stays in the foreground and logs to stderr,
#     which `docker logs` then shows (used to read the resolver's query log).
FROM internetsystemsconsortium/bind9:9.20

RUN apk add --no-cache iproute2

ENTRYPOINT []
CMD ["/usr/sbin/named", "-g", "-c", "/etc/bind/named.conf", "-u", "bind"]
