# Thin wrapper over the ISC BIND 9 image for Protocol Lab.
#
# Why this exists:
#   - The upstream image is built FROM ubuntu:focal and installs only
#     bind9 / bind9utils. It has no `ip` command, but containerlab assigns
#     the lab interface addresses with `ip addr add ...` via exec, so we add
#     iproute2 here.
#   - The upstream CMD is `named -f -c /etc/bind/named.conf -u bind`. We swap
#     `-f` for `-g` so named runs in the foreground and logs to stderr, which
#     `docker logs` then shows (used to read the resolver's query log).
FROM internetsystemsconsortium/bind9:9.20

RUN apt-get -qqqy update \
    && apt-get -qqqy install --no-install-recommends iproute2 \
    && rm -rf /var/lib/apt/lists/*

CMD ["/usr/sbin/named", "-g", "-c", "/etc/bind/named.conf", "-u", "bind"]
