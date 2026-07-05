# BIND 9 + iproute2 for Protocol Lab (see dns-05 for the rationale).
FROM internetsystemsconsortium/bind9:9.20

RUN apt-get -qqqy update \
    && apt-get -qqqy install --no-install-recommends iproute2 \
    && rm -rf /var/lib/apt/lists/*

CMD ["/usr/sbin/named", "-g", "-c", "/etc/bind/named.conf", "-u", "bind"]
