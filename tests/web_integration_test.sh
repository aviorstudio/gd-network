#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
GODOT="${GODOT_BIN:-godot}"
fixture="$(mktemp -d)"
port_file="$(mktemp)"
rm -f "$port_file"
trap 'if [ -n "${server_pid:-}" ]; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$fixture"; rm -f "$port_file"' EXIT

cp -R "$SCRIPT_DIR/web_fixture/." "$fixture/"
mkdir -p "$fixture/addons/@aviorstudio_gd-network" "$fixture/dist"
unzip -q "$ROOT_DIR/dist/@aviorstudio_gd-network.zip" -d "$fixture/addons/@aviorstudio_gd-network"
timeout --signal=TERM --kill-after=5 120 "$GODOT" --headless --path "$fixture" --export-release Web "$fixture/dist/index.html"
python3 "$SCRIPT_DIR/web_fixture_server.py" "$fixture/dist" "$port_file" &
server_pid=$!
for _ in $(seq 1 100); do
    [ -s "$port_file" ] && break
    sleep 0.05
done
test -s "$port_file"
export GD_NETWORK_WEB_URL="http://127.0.0.1:$(<"$port_file")/index.html"
npx playwright test "$SCRIPT_DIR/web_transport.spec.js" --reporter=line
echo "PASS web_integration_test clients=2 requests=11 capacity=typed cancel_callbacks=1"
