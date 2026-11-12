#!/usr/bin/env bash
# Prints the version of each package. On a tag push (<package>-v<version>)
# it also checks that the package has the version of the tag.
# Packages have their own versions. They do not need to be equal.
#
# Env: PACKAGES (from ci/publish-order.sh), GITHUB_REF_TYPE and
# GITHUB_REF_NAME (set by GitHub Actions).
set -euo pipefail

FAIL=0
for entry in $PACKAGES; do
  dir=${entry%%:*}
  v=$(sed -nE 's/^version:[[:space:]]*([^[:space:]]+).*/\1/p' "packages/$dir/pubspec.yaml")
  echo "${entry##*:} $v"
  if [ "${GITHUB_REF_TYPE:-}" = "tag" ] && [ "${GITHUB_REF_NAME#*-v}" != "$v" ]; then
    echo "::error::Tag $GITHUB_REF_NAME does not match the version $v in packages/$dir/pubspec.yaml. Run bin/bump.sh ${entry##*:} ${GITHUB_REF_NAME#*-v}"
    FAIL=1
  fi
done
exit $FAIL
