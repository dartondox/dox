#!/usr/bin/env bash
# Makes the workspace use dox_openapi, dox_validation, ioredis,
# dox_http_native, dox_orm, dox_migration, dox_postgres_native and
# dox_mysql_native from the clones of their repos next to this one
# (../dox-openapi, ../dox-validation, ../ioredis, ../dox-http-native,
# ../dox-orm, ../dox-postgres-native and ../dox-mysql-native, see
# ci/clone-siblings.sh), not the versions on pub.dev. dox_core, dox_cache
# and dox_cache_database depend on them, so lint and the unit tests run on
# their newest code. dox_orm on main can need the newest native drivers,
# so they come from the clones too. dox_migration is not a dependency
# here: the dox_cache_database test that compiles its migration reads it
# from this file.
#
# `ci/use-siblings.sh build` builds the Rust libraries of dox_http_native,
# dox_postgres_native and dox_mysql_native with cargo, only for this
# machine (linux x64 on CI), into ../<repo>/native/target/release. Their
# build hooks take the library from there.
#
# It writes the root pubspec_overrides.yaml (gitignored, so it is never
# committed or published) with absolute paths, because ci/run-group.py
# runs the tests in copies of the repo. Run `dart pub get` after it.
#
# On a tag (a release) it does nothing, so lint and the unit tests use
# pub.dev only.
set -euo pipefail
if [ "${GITHUB_REF_TYPE:-}" = tag ]; then
  echo "tag $GITHUB_REF_NAME: dox_openapi, dox_validation, ioredis, dox_http_native, dox_orm, dox_migration and the native database drivers come from pub.dev"
  exit 0
fi
root=$(cd "$(dirname "$0")/.." && pwd)
parent=$(cd "$root/.." && pwd)

if [ "${1:-}" = build ]; then
  for repo in dox-http-native dox-postgres-native dox-mysql-native; do
    start=$SECONDS
    cargo build --release --manifest-path "$parent/$repo/native/Cargo.toml"
    echo "$repo: built in $((SECONDS - start))s"
  done
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
  dox_orm:
    path: $parent/dox-orm/packages/dox-orm
  dox_migration:
    path: $parent/dox-orm/packages/dox-migration
  dox_postgres_native:
    path: $parent/dox-postgres-native
  dox_mysql_native:
    path: $parent/dox-mysql-native
YAML
echo "dox_openapi, dox_validation, ioredis, dox_http_native, dox_orm, dox_migration and the native database drivers come from $parent"
