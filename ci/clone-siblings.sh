#!/usr/bin/env bash
# Clones the Dox repos that live outside this one next to it:
# ../dox-orm, ../dox-auth, ../dox-openapi, ../dox-validation,
# ../dox-socketio, ../dox-storage, ../dox-queue, ../dox-scheduler,
# ../dox-cli, ../dox-inertia, ../dox-view, ../ioredis, ../dox-http-native,
# ../dox-postgres-native and ../dox-mysql-native. The examples
# (their pubspec_overrides.yaml), ci/use-siblings.sh,
# ci/smoke-template.sh and the dox-test CI use these clones, so they run
# on the newest code of those packages.
# A repo with a branch of the same name as this one (eg. a PR that
# changes both repos) is cloned on that branch, else on main.
# A folder that is already there is kept (local dev).
set -euo pipefail
parent=$(cd "$(dirname "$0")/../.." && pwd)
branch=${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-}}

for repo in dox-orm dox-auth dox-openapi dox-validation dox-socketio dox-storage dox-queue dox-scheduler dox-cli dox-inertia dox-view ioredis \
  dox-http-native dox-postgres-native dox-mysql-native; do
  if [ -d "$parent/$repo" ]; then
    echo "$parent/$repo is there"
    continue
  fi
  url="https://github.com/dartondox/$repo.git"
  # refs/heads/ makes it an exact match. A bare name also matches
  # branches that end with it (feat/main matches main).
  if [ -n "$branch" ] && git ls-remote --exit-code "$url" "refs/heads/$branch" >/dev/null; then
    echo "$repo: branch $branch"
    git clone --depth 1 --branch "$branch" "$url" "$parent/$repo"
  else
    git clone --depth 1 "$url" "$parent/$repo"
  fi
done
