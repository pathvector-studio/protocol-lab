#!/usr/bin/env python3
"""Tiny HTTP identity responder for the anycast lab.

Binds 0.0.0.0:80 (so it answers on the anycast VIP too) and returns its own
name as the body, so a client fetching the VIP can see which instance the
anycast route actually reached. The name is argv[1] (defaults to the hostname).
"""
import http.server
import socket
import sys

NAME = sys.argv[1] if len(sys.argv) > 1 else socket.gethostname()


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = (NAME + "\n").encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    http.server.HTTPServer(("0.0.0.0", 80), Handler).serve_forever()
