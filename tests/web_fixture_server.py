#!/usr/bin/env python3
import http.server
import json
import os
import sys
import time


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/slow/"):
            time.sleep(0.35)
        if self.path.startswith("/slow/") or self.path.startswith("/payload/"):
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
            return
        super().do_GET()

    def log_message(self, _format, *_args):
        return


os.chdir(sys.argv[1])
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(sys.argv[2], "w", encoding="utf-8") as port_file:
    port_file.write(str(server.server_port))
server.serve_forever()
