#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
port_file="$(mktemp)"
rm -f "$port_file"
python3 "$SCRIPT_DIR/http_fixture_server.py" "$port_file" &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; rm -f "$port_file"' EXIT
for _ in $(seq 1 100); do
    [ -s "$port_file" ] && break
    sleep 0.05
done
test -s "$port_file"
export GD_NETWORK_TEST_PORT
GD_NETWORK_TEST_PORT="$(<"$port_file")"
"$SCRIPT_DIR/run_godot_test.sh" "$SCRIPT_DIR/http_native_integration.gd" "PASS gd-network http_native_integration" 30
