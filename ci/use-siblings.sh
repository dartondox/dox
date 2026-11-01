#!/usr/bin/env bash
# Makes the workspace use dox_openapi, dox_validation, ioredis and
# dox_http_native from the clones of their repos next to this one
# (../dox-openapi, ../dox-validation, ../ioredis and ../dox-http-native,
# see ci/clone-siblings.sh), not the versions on pub.dev. dox_core and
# dox_cache depend on them, so lint and the unit tests run on their newest
# code.
#
# `ci/use-siblings.sh build` builds the Rust library of dox_http_native
# with cargo, only for this machine (linux x64 on CI), into
# ../dox-http-native/native/target/release. Its build hook takes the
# library from there.
#
# It writes the root pubspec_overrides.yaml (gitignored, so it is never
# committed or published) with absolute paths, because ci/run-group.py
# runs the tests in copies of the repo. Run `dart pub get` after it.
#
# On a tag (a release) it does nothing, so lint and the unit tests use
# pub.dev only.
set -euo pipefail
if [ "${GITHUB_REF_TYPE:-}" = tag ]; then
  echo "tag $GITHUB_REF_NAME: dox_openapi, dox_validation, ioredis and dox_http_native come from pub.dev"
  exit 0
fi
root=$(cd "$(dirname "$0")/.." && pwd)
parent=$(cd "$root/.." && pwd)

if [ "${1:-}" = build ]; then
  start=$SECONDS
  cargo build --release --manifest-path "$parent/dox-http-native/native/Cargo.toml"
  echo "dox-http-native: built in $((SECONDS - start))s"
  exit 0
fi

cat > "$root/pubspec_overrides.yaml" <<YAML
# written by ci/use-siblings.sh
dependency_overrides:
  dox_openapi:
    path: $parent/dox-openapi
  dox_validation:
    path: $parent/dox-validation
  ioredis:
    path: $parent/ioredis
  dox_http_native:
    path: $parent/dox-http-native
YAML
echo "dox_openapi, dox_validation, ioredis and dox_http_native come from $parent"
