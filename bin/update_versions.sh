#!/usr/bin/env bash
# Sync every package to the version in the root pubspec.yaml.
# - sets `version:` in each packages/*/pubspec.yaml
# - sets every sibling dependency (dox_core, dox_annotation, ...) to ^<version>
# - writes the CLI version constant
# Package names come from each packages/*/pubspec.yaml, so new packages are picked up
# by themselves. dox_app has no version line, only its sibling constraints change.
# Run from the repo root. Safe to run many times. Works with BSD (macOS) and GNU sed.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(sed -nE 's/^version:[[:space:]]*([^[:space:]]+).*/\1/p' pubspec.yaml)
if [ -z "$VERSION" ]; then
  echo "Error: no version in root pubspec.yaml" >&2
  exit 1
fi
echo "Version: $VERSION"

# Names of all packages in this repo (from their `name:` line).
NAMES=$(sed -nE 's/^name:[[:space:]]*([a-z0-9_]+).*/\1/p' packages/*/pubspec.yaml)

for pubspec in packages/*/pubspec.yaml; do
  # Only the top-level version line.
  sed -E -i.bak "s/^version:.*/version: $VERSION/" "$pubspec"
  for name in $NAMES; do
    # Only `  name: <version constraint>` lines. Path/git maps and other values stay as they are.
    sed -E -i.bak "s/^([[:space:]]+$name:)[[:space:]]*['\"]?[\^<>=~0-9][^#]*\$/\1 ^$VERSION/" "$pubspec"
  done
  rm -f "$pubspec.bak"
  echo "Updated $pubspec"
done

echo "const version = '$VERSION';" > packages/dox-cli/lib/src/version.dart
echo "Updated packages/dox-cli/lib/src/version.dart"
