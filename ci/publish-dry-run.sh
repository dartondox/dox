#!/usr/bin/env bash
# Runs `dart pub publish --dry-run` for every package. Nothing is published.
# Warnings only (exit 65) are shown as a warning. Any other error fails.
#
# Env: PACKAGES (from ci/publish-order.sh).
# Run `dart pub get` at the root first, so local sibling versions resolve.
set -euo pipefail

FAIL=0
for entry in $PACKAGES; do
  dir=${entry%%:*}
  echo "::group::$dir"
  code=0
  (cd "packages/$dir" && dart pub publish --dry-run) || code=$?
  echo "::endgroup::"
  # 0 = clean, 65 = warnings only (for example: CHANGELOG, version jump).
  if [ $code -eq 65 ]; then
    echo "::warning::$dir: dry run has warnings. Open the log group to read them."
  elif [ $code -ne 0 ]; then
    echo "::error::$dir: dry run failed (exit $code)"
    FAIL=1
  fi
done
exit $FAIL
