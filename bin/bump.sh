#!/usr/bin/env bash
# Usage: bin/bump.sh <package> <version>, like: bin/bump.sh dox_builder 3.1.4
# Sets `version:` in the pubspec.yaml of that one package. Nothing else
# changes. Other packages and their constraints are not touched.
# If a package needs a newer sibling, raise that constraint by hand.
# Run from anywhere. Works with BSD (macOS) and GNU sed.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ $# -ne 2 ]; then
  echo "Usage: bin/bump.sh <package> <version>" >&2
  exit 1
fi
name=$1
version=$2

if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  echo "Error: bad version '$version'" >&2
  exit 1
fi

for pubspec in packages/*/pubspec.yaml; do
  if [ "$(sed -nE 's/^name:[[:space:]]*([a-z0-9_]+).*/\1/p' "$pubspec")" = "$name" ]; then
    # Only the top-level version line.
    sed -E -i.bak "s/^version:.*/version: $version/" "$pubspec"
    rm -f "$pubspec.bak"
    echo "$pubspec: version $version"
    exit 0
  fi
done
echo "Error: no package named $name in packages/" >&2
exit 1
