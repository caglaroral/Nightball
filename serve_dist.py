#!/usr/bin/env python3
"""Serve the dist/ folder over HTTP so devices on the same network can download the game.

Usage: python3 serve_dist.py [port]     (default port 8000)
"""
import functools
import http.server
import os
import socket
import sys

DIST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dist")


def lan_addresses():
    """Best guess at this computer's LAN IPv4 address."""
    addresses = set()
    try:
        # No packet is sent; connect() on UDP only picks the outgoing interface.
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("192.168.0.1", 9))
            addresses.add(s.getsockname()[0])
    except OSError:
        pass
    return sorted(addresses) or ["127.0.0.1"]


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".apk": "application/vnd.android.package-archive",
        ".zip": "application/zip",
    }


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    if not os.path.isdir(DIST):
        sys.exit("dist/ does not exist yet; build it with godot/tools/export_all.sh")
    handler = functools.partial(Handler, directory=DIST)
    server = http.server.ThreadingHTTPServer(("0.0.0.0", port), handler)
    for address in lan_addresses():
        print(f"Serving {DIST} at http://{address}:{port}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
