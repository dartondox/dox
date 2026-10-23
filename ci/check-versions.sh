#!/usr/bin/env bash
# Checks that every package has the same version as the root pubspec.yaml.
# On a tag push it also checks that the tag (v<version>) matches it.
#
# Env: PACKAGES (from ci/publish-order.sh), GITHUB_REF_TYPE and
# GITHUB_REF_NAME (set by GitHub Actions).
set -euo pipefail

VERSION=$(sed -nE 's/^version:[[:space:]]*([^[:space:]]+).*/\1/p' pubspec.yaml)
echo "Root version: $VERSION"
if [ "${GITHUB_REF_TYPE:-}" = "tag" ] && [ "${GITHUB_REF_NAME#v}" != "$VERSION" ]; then
  echo "::error::Tag $GITHUB_REF_NAME does not match root pubspec version $VERSION"
  exit 1
fi
FAIL=0
for entry in $PACKAGES; do
  dir=${entry%%:*}
  v=$(sed -nE 's/^version:[[:space:]]*([^[:space:]]+).*/\1/p' "packages/$dir/pubspec.yaml")
  if [ "$v" != "$VERSION" ]; then
    echo "::error::packages/$dir has version $v, expected $VERSION. Run bin/update_versions.sh"
    FAIL=1
  fi
done
exit $FAIL
