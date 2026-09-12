#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 SCRIPT EXPECTED_SENTINEL [TIMEOUT_SECONDS]" >&2
    exit 2
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR="${GODOT_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
GODOT="${GODOT_BIN:-godot}"
script="$1"
sentinel="$2"
timeout_seconds="${3:-60}"

if [ ! -f "$script" ]; then
    echo "Missing Godot test script: $script" >&2
    exit 1
fi

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
set +e
timeout --signal=TERM --kill-after=5 "$timeout_seconds" \
    "$GODOT" --headless --path "$ROOT_DIR" --script "$script" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
set -e

if [ "$status" -eq 124 ] || [ "$status" -eq 137 ]; then
    echo "Godot test timed out after ${timeout_seconds}s: $script" >&2
    exit 1
fi
if [ "$status" -ne 0 ]; then
    echo "Godot test exited with status $status: $script" >&2
    exit 1
fi
if grep -Eq '(^|[[:space:]])(SCRIPT ERROR:|ERROR:)' "$log"; then
    echo "Godot test emitted an unexpected engine/runtime error: $script" >&2
    exit 1
fi
sentinel_count="$(grep -Fxc "$sentinel" "$log" || true)"
if [ "$sentinel_count" -ne 1 ]; then
    echo "Expected exactly one reachable sentinel '$sentinel'; found $sentinel_count: $script" >&2
    exit 1
fi
