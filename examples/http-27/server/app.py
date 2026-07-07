#!/usr/bin/env python3
"""Tiny HTTP server for Protocol Lab #27 (redirects and cookies).

Routes:
  GET /old      -> 302 Found, Location: /new           (a redirect)
  GET /new      -> 200, Set-Cookie: session=abc123      (hands out a cookie)
  GET /whoami   -> 200, echoes the Cookie header back    (reads the cookie)

No dependencies beyond the standard library (netshoot ships python3).
"""
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = 8080


class Handler(BaseHTTPRequestHandler):
    server_version = "protocol-lab/1.0"
    protocol_version = "HTTP/1.1"  # we always send Content-Length

    def _send(self, code, body=b"", headers=None):
        self.send_response(code)
        for k, v in (headers or []):
            self.send_header(k, v)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self):
        if self.path == "/old":
            # A redirect: tell the client to go to /new instead.
            self._send(302, b"moved\n", [("Location", "/new")])
        elif self.path == "/new":
            # Hand out a cookie the client should store and send back later.
            self._send(
                200,
                b"welcome (a cookie was set)\n",
                [("Set-Cookie", "session=abc123; Path=/")],
            )
        elif self.path == "/whoami":
            # Read the cookie the client sent.
            cookie = self.headers.get("Cookie", "(no cookie)")
            self._send(200, ("you sent Cookie: %s\n" % cookie).encode())
        else:
            self._send(404, b"not found\n")

    def log_message(self, fmt, *args):
        pass  # quiet


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
