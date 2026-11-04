#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
run_assertion() {
    python3 "$TOOLS_ROOT/helpers/godot-test.py" --project "$SCRIPT_DIR/.." \
        --program "$1" --sentinel "$2" --timeout "${3:-60}"
}
fixtures="$SCRIPT_DIR/gate_fixtures"
controls=0

expect_failure() {
    local label="$1"
    shift
    if "$@"; then
        echo "Negative runner control unexpectedly passed: $label" >&2
        exit 1
    fi
    controls=$((controls + 1))
    echo "CONTROL_FAIL_OK $label"
}

expect_failure runtime-error-zero run_assertion "$fixtures/runtime_error_zero.gd" NEVER 5
expect_failure overwritten-quit run_assertion "$fixtures/overwritten_quit.gd" NEVER 5
expect_failure parse-unreachable run_assertion "$fixtures/parse_unreachable.gd" NEVER 5
expect_failure timeout run_assertion "$fixtures/timeout.gd" NEVER 1
expect_failure missing-script run_assertion "$fixtures/missing.gd" NEVER 1
expect_failure unreachable-sentinel run_assertion "$fixtures/no_sentinel.gd" NEVER 5

run_assertion "$fixtures/passing.gd" "GATE_FIXTURE_REACHED" 5
if [ "$controls" -ne 6 ]; then
    echo "Expected six negative controls, observed $controls" >&2
    exit 1
fi
echo "PASS runner_self_test controls=$controls restored=1 reachable=1"
