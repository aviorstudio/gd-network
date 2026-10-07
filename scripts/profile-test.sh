#!/usr/bin/env bash
set -euo pipefail
bash tests/runner_self_test.sh
bash tests/release_recovery_test.sh
bash tests/test.sh
bash tests/http_integration_test.sh
