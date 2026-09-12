#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
runner="$SCRIPT_DIR/run_godot_test.sh"
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

expect_failure runtime-error-zero "$runner" "$fixtures/runtime_error_zero.gd" NEVER 5
expect_failure overwritten-quit "$runner" "$fixtures/overwritten_quit.gd" NEVER 5
expect_failure parse-unreachable "$runner" "$fixtures/parse_unreachable.gd" NEVER 5
expect_failure timeout "$runner" "$fixtures/timeout.gd" NEVER 1
expect_failure missing-script "$runner" "$fixtures/missing.gd" NEVER 1
expect_failure unreachable-sentinel "$runner" "$fixtures/no_sentinel.gd" NEVER 5

"$runner" "$fixtures/passing.gd" "GATE_FIXTURE_REACHED" 5
if [ "$controls" -ne 6 ]; then
    echo "Expected six negative controls, observed $controls" >&2
    exit 1
fi
echo "PASS runner_self_test controls=$controls restored=1 reachable=1"
