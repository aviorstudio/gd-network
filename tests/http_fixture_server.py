#!/usr/bin/env python3
import http.server
import json
import sys
import time


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/slow/"):
            time.sleep(0.35)
        if self.path == "/large":
            payload = json.dumps({"value": "x" * 4096}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        if self.path.startswith("/redirect/"):
            remaining = int(self.path.rsplit("/", 1)[1])
            self.send_response(302)
            self.send_header("Location", f"/redirect/{remaining - 1}" if remaining else "/payload/final")
            self.end_headers()
            return
        identity = self.path.rsplit("/", 1)[-1]
        payload = json.dumps({"id": identity}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        try:
            self.wfile.write(payload)
        except BrokenPipeError:
            pass

    def log_message(self, _format, *_args):
        return


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(sys.argv[1], "w", encoding="utf-8") as port_file:
    port_file.write(str(server.server_port))
server.serve_forever()
