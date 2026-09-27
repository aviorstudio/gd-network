#!/usr/bin/env python3
import http.server
import json
import os
import sys
import threading
import time


SINK_PORT = 0
SINK_HITS = ""


class SinkHandler(http.server.BaseHTTPRequestHandler):
    def _record(self):
        length_header = self.headers.get("Content-Length")
        body = b""
        if length_header not in (None, ""):
            body = self.rfile.read(int(length_header))
        with open(SINK_HITS, "a", encoding="utf-8") as hits:
            hits.write(
                "%s %s auth=%s bytes=%d\n"
                % (self.command, self.path, self.headers.get("Authorization", ""), len(body))
            )
        self.send_response(204)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        self._record()

    def do_POST(self):
        self._record()

    def do_HEAD(self):
        self._record()

    def log_message(self, _format, *_args):
        return


class Handler(http.server.SimpleHTTPRequestHandler):
    def _read_body(self):
        length_header = self.headers.get("Content-Length")
        if length_header in (None, ""):
            return b""
        return self.rfile.read(int(length_header))

    def _send_json(self, payload):
        encoded = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try:
            self.wfile.write(encoded)
        except BrokenPipeError:
            pass

    def do_POST(self):
        body = self._read_body()
        path = self.path.split("?", 1)[0]
        authorization = self.headers.get("Authorization", "")
        token_in_body = b"secret-token-not-in-body" in body
        if path == "/zero":
            self._send_json(
                {
                    "id": "zero",
                    "bytes": len(body),
                    "content_type": self.headers.get("Content-Type", ""),
                    "has_authorization": authorization.startswith("Bearer "),
                    "token_in_body": token_in_body,
                }
            )
            return
        if path == "/json-empty":
            self._send_json(
                {
                    "id": "json",
                    "body": body.decode("utf-8", "replace"),
                    "bytes": len(body),
                    "content_type": self.headers.get("Content-Type", ""),
                    "token_in_body": token_in_body,
                }
            )
            return
        self.send_error(404)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/redirect-cross":
            self.send_response(302)
            self.send_header("Location", "http://127.0.0.1:%d/must-not-follow" % SINK_PORT)
            self.send_header("Content-Length", "0")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            return
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
SINK_HITS = sys.argv[2] + ".sink-hits"
open(SINK_HITS, "w", encoding="utf-8").close()
sink = http.server.ThreadingHTTPServer(("127.0.0.1", 0), SinkHandler)
SINK_PORT = sink.server_port
threading.Thread(target=sink.serve_forever, daemon=True).start()
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(sys.argv[2], "w", encoding="utf-8") as port_file:
    port_file.write(str(server.server_port))
with open(sys.argv[2] + ".sink", "w", encoding="utf-8") as sink_file:
    sink_file.write(str(SINK_PORT))
server.serve_forever()
