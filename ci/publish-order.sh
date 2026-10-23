#!/usr/bin/env bash
# Prints the packages in publish order, as folder:package, one per line.
# Also saves them as PACKAGES (space separated) in $GITHUB_ENV, so the next
# steps of the job can use them. Outside of GitHub Actions it only prints.
#
# bin/publish_order.py sorts the packages by their pubspecs: each one comes
# after every sibling it depends on (dev_dependencies too, pub checks them
# on publish).
set -euo pipefail

PACKAGES=$(python3 bin/publish_order.py | tr '\n' ' ')
echo "$PACKAGES" | tr ' ' '\n'
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "PACKAGES=$PACKAGES" >> "$GITHUB_ENV"
fi
