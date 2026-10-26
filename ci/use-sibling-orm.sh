#!/usr/bin/env bash
# Makes the workspace use dox_orm and dox_migration from the clone of
# dox-orm next to this repo (../dox-orm, see ci/clone-siblings.sh), not
# the versions on pub.dev. So lint and the unit tests run on the newest
# ORM code, like the examples and the template smoke test.
#
# It writes the root pubspec_overrides.yaml (gitignored, so it is never
# committed or published) with absolute paths, because ci/run-group.py
# runs the tests in copies of the repo. Run `dart pub get` after it.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
orm=$(cd "$root/../dox-orm" && pwd)

cat > "$root/pubspec_overrides.yaml" <<YAML
# written by ci/use-sibling-orm.sh
dependency_overrides:
  dox_orm:
    path: $orm/packages/dox-orm
  dox_migration:
    path: $orm/packages/dox-migration
YAML
echo "dox_orm and dox_migration come from $orm"
