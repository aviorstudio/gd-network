#!/usr/bin/env bash
set -euo pipefail
bash scripts/verify_package_checksum.sh
bash tests/package_test.sh
bash tests/web_integration_test.sh
