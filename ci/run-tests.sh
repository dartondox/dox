#!/usr/bin/env bash
# Runs `dart test` in each package, one log group per package.
#
# Env: TEST_PACKAGES: folders under packages/, space separated.
#      TEST_VARS: env vars for `dart test`, like "DRIVER=mysql DB_PORT=3306".
#      Can be empty.
#      NO_LOG_GROUPS=1: print "== <package>" lines, not ::group:: lines
#      (ci/run-group.py puts the whole log in one group).
set -euo pipefail

group_start="::group::"
group_end="::endgroup::"
if [ "${NO_LOG_GROUPS:-}" = 1 ]; then group_start="== "; group_end=""; fi

for p in $TEST_PACKAGES; do
  echo "$group_start$p"
  # TEST_VARS is split into words on purpose: one word per env var.
  # shellcheck disable=SC2086
  (cd "packages/$p" && env ${TEST_VARS:-} dart test)
  echo "$group_end"
done
