#!/usr/bin/env bash
# Checks each package to release (PACKAGES, from ci/publish-order.sh)
# against pub.dev only. In the pub workspace, sibling packages come from
# local folders, so a missing release would not show. So each package is
# copied to a temp folder outside the workspace. There, `resolution:
# workspace` is removed and every dependency comes from pub.dev. Then it
# runs `dart pub get` (with retries, see ci/pub-get-retry.sh) and
# `dart analyze --no-fatal-warnings`.
# On a tag only the tagged package is checked, so no sibling is replaced.
set -euo pipefail
cd "$(dirname "$0")/.."
root=$PWD
tmp=${RUNNER_TEMP:-$(mktemp -d)}

for entry in ${PACKAGES:?PACKAGES is empty, run ci/publish-order.sh first}; do
  dir=${entry%%:*}
  work="$tmp/pub-check/$dir"
  rm -rf "$work"
  mkdir -p "$work"
  cp -R "packages/$dir/." "$work/"
  rm -f "$work/pubspec_overrides.yaml" "$work/pubspec.lock"
  sed -i.bak '/^resolution:[[:space:]]*workspace/d' "$work/pubspec.yaml"
  rm -f "$work/pubspec.yaml.bak"
  echo "== $entry (from pub.dev)"
  (cd "$work" && "$root/ci/pub-get-retry.sh" && dart analyze --no-fatal-warnings)
done
