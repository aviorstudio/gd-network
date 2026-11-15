#!/usr/bin/env python3
import http.server
import json
import sys
import time
import threading
import urllib.request
from pathlib import Path


target_hits = {"requests": 0, "authorization_present": False, "authorized_redirect_requests": 0}
target_file = Path(sys.argv[2])


def record_target(headers):
    target_hits["requests"] += 1
    target_hits["authorization_present"] |= bool(headers.get("Authorization"))
    target_file.write_text(json.dumps(target_hits), encoding="utf-8")


class SinkHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        record_target(self.headers)
        self.send_response(200)
        self.end_headers()

    def log_message(self, _format, *_args):
        return


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/problem":
            payload = json.dumps({"error": {"code": "operation_conflict", "message": "Keep the saved operation", "request_id": "server-409"}}).encode()
            self.send_response(409)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
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
        if self.path in {"/redirect-same", "/redirect-cross"}:
            if self.headers.get("Authorization") == "Bearer native-redirect-secret":
                target_hits["authorized_redirect_requests"] += 1
                target_file.write_text(json.dumps(target_hits), encoding="utf-8")
            self.send_response(302)
            target = "/must-not-follow" if self.path == "/redirect-same" else f"http://127.0.0.1:{sink.server_port}/must-not-follow"
            self.send_header("Location", target)
            self.end_headers()
            return
        if self.path == "/must-not-follow":
            record_target(self.headers)
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


sink = http.server.ThreadingHTTPServer(("127.0.0.1", 0), SinkHandler)
threading.Thread(target=sink.serve_forever, daemon=True).start()
# Prove the independent sink records requests and Authorization before the test.
request = urllib.request.Request(f"http://127.0.0.1:{sink.server_port}/must-not-follow", headers={"Authorization": "Bearer negative-control"})
with urllib.request.urlopen(request, timeout=2) as response:
    assert response.status == 200
assert target_hits == {"requests": 1, "authorization_present": True, "authorized_redirect_requests": 0}
target_hits.update(requests=0, authorization_present=False)
target_file.write_text(json.dumps(target_hits), encoding="utf-8")
print("PASS native redirect sink negative control", flush=True)
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(sys.argv[1], "w", encoding="utf-8") as port_file:
    port_file.write(str(server.server_port))
server.serve_forever()
