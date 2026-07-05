# Thin wrapper over the official Caddy image for Protocol Lab #11.
#
# Caddy serves HTTP/1.1, HTTP/2 (over TLS), and HTTP/3 (QUIC over UDP) from a
# single binary with an internal CA, which makes it ideal for comparing
# stream behavior across transports.
#
# We add iproute2 only because containerlab assigns the lab interface address
# with `ip addr add ...` via exec, and the base Caddy (Alpine) image does not
# include a full `ip`.
FROM caddy:2

RUN apk add --no-cache iproute2

# The base image already runs: caddy run --config /etc/caddy/Caddyfile
# We bind-mount our Caddyfile there, so no CMD override is needed.
