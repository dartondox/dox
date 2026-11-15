#!/usr/bin/env bash
# Runs `dart pub get` with the given args. A version that was just
# published can take a few minutes to show on pub.dev. So when pub cannot
# find a version, it tries again every 20 seconds, for up to 5 minutes.
# Any other error fails at once.
set -euo pipefail

TRIES=16 # the first try, then 15 waits of 20 seconds
log=$(mktemp)
for i in $(seq 1 "$TRIES"); do
  code=0
  dart pub get "$@" 2>&1 | tee "$log" || code=$?
  [ "$code" -eq 0 ] && exit 0
  grep -qE "doesn't match any versions|version solving failed" "$log" || exit "$code"
  [ "$i" -eq "$TRIES" ] && break
  echo "pub.dev may not show a new version yet ($i/$TRIES). Trying again in 20 seconds."
  sleep 20
done
echo "::error::dart pub get still fails after 5 minutes"
exit "$code"
