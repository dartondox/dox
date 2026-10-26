#!/usr/bin/env bash
# Makes the workspace use dox_openapi and dox_validation from the clones
# of their repos next to this one (../dox-openapi and ../dox-validation,
# see ci/clone-siblings.sh), not the versions on pub.dev. dox_core
# depends on them, so lint and the unit tests run on their newest code.
#
# It writes the root pubspec_overrides.yaml (gitignored, so it is never
# committed or published) with absolute paths, because ci/run-group.py
# runs the tests in copies of the repo. Run `dart pub get` after it.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
parent=$(cd "$root/.." && pwd)

cat > "$root/pubspec_overrides.yaml" <<YAML
# written by ci/use-siblings.sh
dependency_overrides:
  dox_openapi:
    path: $parent/dox-openapi
  dox_validation:
    path: $parent/dox-validation
YAML
echo "dox_openapi and dox_validation come from $parent"
