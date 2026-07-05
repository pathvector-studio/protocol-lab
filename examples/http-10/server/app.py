#!/usr/bin/env python3
"""Tiny HTTP/1.1 server for Protocol Lab #10.

It exists to make HTTP methods, status codes, and cache headers observable:

  GET  /            -> 200 with Cache-Control + ETag (conditional-aware)
  HEAD /            -> 200 headers only, no body
  GET  / (If-None-Match matches) -> 304 Not Modified (no body)
  GET  /missing     -> 404 Not Found

Closed lab use only; not a production server.
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
import sys

ETAG = '"v1-abc123"'
BODY = b"Hello from the Protocol Lab HTTP server.\n"
MAX_AGE = "max-age=60"


class Handler(BaseHTTPRequestHandler):
    server_version = "protocol-lab/1.0"
    protocol_version = "HTTP/1.1"  # enables persistent connections + keep-alive

    def _send_headers(self, status, length):
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(length))
        self.send_header("Cache-Control", MAX_AGE)
        self.send_header("ETag", ETAG)
        self.end_headers()

    def do_GET(self):
        if self.path == "/missing":
            self.send_response(404)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        if self.headers.get("If-None-Match") == ETAG:
            # The client already has this representation; tell it so, no body.
            self.send_response(304)
            self.send_header("ETag", ETAG)
            self.send_header("Cache-Control", MAX_AGE)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        self._send_headers(200, len(BODY))
        self.wfile.write(BODY)

    def do_HEAD(self):
        self._send_headers(200, len(BODY))

    def log_message(self, fmt, *args):
        sys.stderr.write("[http] %s - %s\n" % (self.address_string(), fmt % args))


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
