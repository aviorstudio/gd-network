#!/bin/bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FAILURES=0
shopt -s nullglob
tests=("$SCRIPT_DIR"/*_test.gd)
if [ "${#tests[@]}" -eq 0 ]; then
    echo "No Godot test scripts matched tests/*_test.gd" >&2
    exit 1
fi
for test in "${tests[@]}"; do
    echo "Running $(basename "$test")..."
    sentinel="PASS gd-network $(basename "$test" .gd)"
    if ! "$SCRIPT_DIR/run_godot_test.sh" "$test" "$sentinel" 60; then
        FAILURES=$((FAILURES + 1))
    fi
done
exit $FAILURES
