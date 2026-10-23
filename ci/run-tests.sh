#!/usr/bin/env bash
# Runs `dart test` in each package, one log group per package.
#
# Env: TEST_PACKAGES: folders under packages/, space separated.
#      TEST_VARS: env vars for `dart test`, like "DRIVER=mysql DB_PORT=3306".
#      Can be empty.
set -euo pipefail

for p in $TEST_PACKAGES; do
  echo "::group::$p"
  # TEST_VARS is split into words on purpose: one word per env var.
  # shellcheck disable=SC2086
  (cd "packages/$p" && env ${TEST_VARS:-} dart test --concurrency=1)
  echo "::endgroup::"
done
