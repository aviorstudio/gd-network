#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
port_file="$(mktemp)"
target_file="$(mktemp)"
rm -f "$port_file"
python3 "$SCRIPT_DIR/http_fixture_server.py" "$port_file" "$target_file" &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; rm -f "$port_file" "$target_file"' EXIT
for _ in $(seq 1 100); do
    [ -s "$port_file" ] && break
    sleep 0.05
done
test -s "$port_file"
export GD_NETWORK_TEST_PORT
GD_NETWORK_TEST_PORT="$(<"$port_file")"
python3 "$TOOLS_ROOT/helpers/godot-test.py" --project "$SCRIPT_DIR/.." --program "$SCRIPT_DIR/http_native_integration.gd" --sentinel "PASS gd-network http_native_integration" --timeout 30
python3 - "$target_file" <<'PYCODE'
import json
import sys
from pathlib import Path
assert json.loads(Path(sys.argv[1]).read_text()) == {"requests": 0, "authorization_present": False, "authorized_redirect_requests": 2}, "Redirect target was contacted or received Authorization"
PYCODE
