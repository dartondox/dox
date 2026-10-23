#!/usr/bin/env bash
# Runs `dart test` in each package, one log group per package.
#
# Env: TEST_PACKAGES: folders under packages/, space separated.
#      TEST_VARS: env vars for `dart test`, like "DRIVER=mysql DB_PORT=3306".
#      Can be empty.
set -euo pipefail

# Test files run in parallel. These packages run one file at a time:
# - dox-orm, dox-migration, dox-postgres-native, dox-mysql-native: the test
#   files create and drop the same tables in one database.
# - dox-cli: the tests change the working folder. It is shared by all files.
serial=" dox-orm dox-migration dox-postgres-native dox-mysql-native dox-cli "

for p in $TEST_PACKAGES; do
  echo "::group::$p"
  jobs=""
  if [[ "$serial" == *" $p "* ]]; then jobs="--concurrency=1"; fi
  # TEST_VARS is split into words on purpose: one word per env var.
  # shellcheck disable=SC2086
  (cd "packages/$p" && env ${TEST_VARS:-} dart test $jobs)
  echo "::endgroup::"
done
